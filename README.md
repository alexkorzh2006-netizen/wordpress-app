# WordPress and OpenVPN on AWS

This project creates two Ubuntu EC2 instances in a dedicated, nondefault VPC:

- a `t3.small` WordPress host with MariaDB installed locally by cloud-init;
- a `t3.micro` OpenVPN gateway configured by Ansible.

WordPress is reached through its private VPC address after connecting to
OpenVPN. It is not allowed to receive HTTP, HTTPS, or SSH directly from the
internet. Cloudflare provides DNS only, while Certbot installs a publicly
trusted HTTPS certificate directly on Apache.

## Architecture

```text
Windows OpenVPN client
        |
        | UDP/1194 to the stable Elastic IP
        v
OpenVPN EC2 (10.20.1.10, AZ 1)
        |
        | encrypted client traffic, routed and SNATed inside the VPC
        v
WordPress + MariaDB EC2 (private address, AZ 2)
        |
        +-- Apache/WordPress: HTTPS with a Let's Encrypt certificate
        +-- MariaDB: localhost only
```

The WordPress instance receives a temporary public IPv4 address only so
cloud-init can download operating-system packages and WordPress. Its security
group accepts no internet ingress. HTTP, HTTPS, and SSH are accepted only from
the OpenVPN instance's fixed private address.

## Security boundaries

- OpenVPN UDP `1194` and public SSH are restricted to the trusted CIDRs in
  `terraform/networking/terraform.tfvars`.
- WordPress HTTP, HTTPS, and SSH accept traffic only from `10.20.1.10/32`, the
  OpenVPN gateway's private address.
- MariaDB listens on `127.0.0.1` and is usable only by WordPress on the same
  instance.
- No inbound security-group rule permits `0.0.0.0/0`.
- The OpenVPN role pushes the VPC route `10.20.0.0/16` to clients and performs
  source NAT when it forwards traffic to WordPress.
- The Cloudflare record is DNS-only and points to the WordPress private IP.
- Certbot proves domain ownership through Cloudflare DNS-01, so certificate
  issuance does not require public web access.

## Local configuration

Create `terraform/networking/terraform.tfvars`:

```hcl
ssh_allowed_cidrs = ["YOUR_PUBLIC_IP/32"]
vpn_allowed_cidrs = ["YOUR_PUBLIC_IP/32"]
```

Find your current address with:

```bash
curl -4 -fsS https://checkip.amazonaws.com
```

Create `terraform/ec2/terraform.tfvars`:

```hcl
key_name              = "wordpress-host-key"
wordpress_domain      = "wordpress.example.com"
wordpress_admin_email = "admin@example.com"
cloudflare_zone_id    = "YOUR_32_CHARACTER_ZONE_ID"
certificate_email     = "certificates@example.com"
```

The key-pair name, domain, and Zone ID are identifiers rather than credentials.
Keep the private `.pem` file outside the repository, for example at
`~/.ssh/wordpress-host-key.pem`.

Create a Cloudflare API token restricted to this zone with `Zone:DNS:Edit`.
Do not put the token in `.tfvars`. Load it without writing it to shell history:

```bash
read -rsp "Cloudflare API token: " CLOUDFLARE_API_TOKEN
export CLOUDFLARE_API_TOKEN
echo
```

## Deploy

Run these commands from the repository root.

### 1. Create the VPC and security groups

```bash
terraform -chdir=terraform/networking init
terraform -chdir=terraform/networking plan
terraform -chdir=terraform/networking apply
```

### 2. Create both EC2 instances and Cloudflare DNS

```bash
terraform -chdir=terraform/ec2 init
terraform -chdir=terraform/ec2 plan
terraform -chdir=terraform/ec2 apply
```

Terraform creates a DNS-only Cloudflare `A` record containing the WordPress
private IP. Cloudflare proxying is intentionally disabled because the origin
is reachable only through OpenVPN.

Get the new VPN address and add its SSH host key:

```bash
VPN_IP="$(terraform -chdir=terraform/ec2 output -raw vpn_public_ip)"
ssh-keygen -R "$VPN_IP" 2>/dev/null || true
ssh-keyscan -H "$VPN_IP" >> "$HOME/.ssh/known_hosts"
```

WordPress installs independently on the other EC2 instance through cloud-init.
Its private URL is available from Terraform immediately, but the application
can take several minutes to finish installing.

### 3. Configure OpenVPN and the HTTPS certificate

```bash
cd ansible
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install ansible boto3 botocore
ansible-galaxy install -r requirements.yml
```

The inventory already uses the AWS profile `default`. Check that it discovers
both tagged instances and creates the
`role_openvpn` and `role_wordpress` groups:

```bash
ansible-inventory --graph
```

The group variables read the approved SSH and VPN CIDRs, domain, certificate
email, VPN address, and private-key path from Terraform outputs. Keep
`CLOUDFLARE_API_TOKEN` exported and run the playbook without extra arguments:

```bash
ansible-playbook playbook.yml

cd ..
```

Ansible first configures `role_openvpn`. It then reaches `role_wordpress`
through the VPN EC2 instance as an SSH jump host, installs Certbot's Apache and
Cloudflare plugins, requests the certificate with DNS-01, enables automatic
renewal, and changes the WordPress URLs to the HTTPS domain. The VPN client
profile is written to:

```text
ansible/client-configs/admin-wordpress-openvpn.ovpn
```

The profile contains a private client key and is ignored by Git.

## Connect from Windows

Copy the generated profile into Windows Downloads:

```bash
cp ansible/client-configs/admin-wordpress-openvpn.ovpn \
  "/mnt/c/Users/$(powershell.exe -NoProfile -Command '$env:USERNAME' | tr -d '\r')/Downloads/"
```

Import `admin-wordpress-openvpn.ovpn` into OpenVPN Connect and connect. Then
open WordPress:

```bash
explorer.exe "$(terraform -chdir=terraform/ec2 output -raw wordpress_url)"
```

The domain resolves to a private IP and should not be reachable while the VPN
is disconnected.

## Useful outputs

```bash
terraform -chdir=terraform/ec2 output
terraform -chdir=terraform/ec2 output -raw vpn_public_ip
terraform -chdir=terraform/ec2 output -raw wordpress_private_ip
terraform -chdir=terraform/ec2 output -raw wordpress_domain
terraform -chdir=terraform/ec2 output -raw wordpress_url
terraform -chdir=terraform/ec2 output -raw wordpress_admin_password
echo
```

Terraform state contains the generated WordPress password in plaintext. The
local state files and local `.tfvars` files are ignored by Git.

## Verification

After connecting the VPN:

```bash
dig +short "$(terraform -chdir=terraform/ec2 output -raw wordpress_domain)"
curl -I "$(terraform -chdir=terraform/ec2 output -raw wordpress_url)"
```

Check Certbot renewal on the WordPress host through the SSH jump host:

```bash
(
  cd ansible
  ansible role_wordpress --become --module-name command \
    --args 'certbot renew --dry-run'
)
```

Check the OpenVPN service through its public endpoint:

```bash
ssh -i "$HOME/.ssh/wordpress-host-key.pem" \
  ubuntu@"$(terraform -chdir=terraform/ec2 output -raw vpn_public_ip)" \
  'sudo systemctl is-active openvpn-server@openvpn_udp_1194 && sudo ss -lunp | grep ":1194"'
```

## Destroy

Destroy EC2 before networking because both instances depend on VPC resources:

```bash
terraform -chdir=terraform/ec2 destroy
terraform -chdir=terraform/networking destroy
```

## Important migration note

Applying this change replaces the old combined EC2 instance because WordPress
and OpenVPN are now separate machines. Any content stored only on the old
instance should be backed up before applying. Terraform does not automatically
migrate the existing WordPress database or uploaded media.
