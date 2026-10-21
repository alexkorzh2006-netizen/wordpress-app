# OpenVPN configuration

This directory configures the dedicated OpenVPN instance. WordPress and its
HTTPS certificate are installed by cloud-init independently of Ansible.

The AWS inventory plugin discovers running instances tagged
`Project=wordpress-host` and creates groups from their `Role` tags. The
playbook targets `role_openvpn`. The downloaded `kyl191.openvpn` role installs
the service, generates client certificates, pushes the `10.20.0.0/16` VPC
route, and fetches the client profile. Project-owned post-tasks replace the
role's unrestricted UFW entry with rules limited to the CIDRs read from
Terraform outputs.

## Install dependencies

From this directory:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install ansible boto3 botocore
ansible-galaxy install -r requirements.yml
```

The pinned role and collections are declared in `requirements.yml` and are
downloaded under `.galaxy/`, which is ignored by Git.

## Run

Add the VPN Elastic IP to `known_hosts` from the repository root:

```bash
VPN_IP="$(terraform -chdir=terraform/ec2 output -raw vpn_public_ip)"
ssh-keygen -R "$VPN_IP" 2>/dev/null || true
ssh-keyscan -H "$VPN_IP" >> "$HOME/.ssh/known_hosts"
```

Then run from `ansible/`:

```bash
ansible-inventory --graph
```

The inventory uses AWS profile `default`. Group variables use
`~/.ssh/wordpress-host-key.pem` and read `vpn_allowed_cidrs` and
`ssh_allowed_cidrs` directly from the applied networking Terraform state:

```bash
ansible-playbook playbook.yml
```

The generated profile is:

```text
client-configs/admin-wordpress-openvpn.ovpn
```

It contains a private client key. Do not commit or share it.

After importing the profile and connecting, browse to the private URL returned
by:

```bash
terraform -chdir=../terraform/ec2 output -raw wordpress_url
```
