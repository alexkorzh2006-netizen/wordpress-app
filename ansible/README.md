# OpenVPN access for the WordPress EC2 instance

This directory configures the existing Ubuntu EC2 instance as an OpenVPN
server. WordPress remains on the same instance and is opened by its private
`10.20.x.x` address after the VPN connects.

## Security model

- AWS exposes UDP `1194` only to CIDRs listed in `vpn_allowed_cidrs`.
- AWS exposes HTTP/HTTPS only inside the `10.20.0.0/16` VPC.
- UFW allows HTTP/HTTPS only on the `tun0` VPN interface.
- OpenVPN authenticates every client with a separate certificate.
- The role changes WordPress `home` and `siteurl` to the EC2 private address.
- No inbound Terraform rule uses `0.0.0.0/0`. The unrestricted egress rule is
  outbound traffic and does not expose the instance.

The public Elastic IP is used only to establish the VPN tunnel. The browser
then reaches the WordPress private IP through that encrypted tunnel.

## 1. Configure the AWS entry rules

Create or edit `terraform/networking/terraform.tfvars`:

```hcl
vpn_allowed_cidrs = ["YOUR_CURRENT_PUBLIC_IP/32"]
ssh_allowed_cidrs = ["YOUR_CURRENT_PUBLIC_IP/32"]
```

The SSH rule is required for the first Ansible run. Both variables reject
`0.0.0.0/0`. Also set an existing EC2 key-pair name in
`terraform/ec2/terraform.tfvars`:

```hcl
key_name = "your-key-pair-name"
```

Apply networking before EC2 because EC2 reads the networking state:

```bash
terraform -chdir=terraform/networking apply
terraform -chdir=terraform/ec2 apply
```

## 2. Configure Ansible

Put the same `/32` CIDR in `group_vars/vpn_servers.yml`:

```yaml
openvpn_admin_cidrs:
  - YOUR_CURRENT_PUBLIC_IP/32
```

Create a Python environment and install the required collections:

```bash
cd ansible
python3 -m venv .venv
. .venv/bin/activate
python -m pip install ansible boto3 botocore
ansible-galaxy collection install -r requirements.yml
```

The dynamic inventory discovers the instance by its
`Name=wordpress-host-ec2` AWS tag, so its IP is not hardcoded in inventory.
Check discovery:

```bash
ansible-inventory --graph
```

Add the instance SSH host key, then run the role using the private key that
matches `key_name`:

```bash
ssh-keyscan -H "$(terraform -chdir=../terraform/ec2 output -raw public_ip)" >> ~/.ssh/known_hosts
ansible-playbook playbook.yml --private-key ~/.ssh/your-key.pem
```

Ansible writes the client profile to
`ansible/client-configs/wordpress-host-ec2-admin.ovpn`. That directory is
ignored by Git because the profile contains a private client key.

## 3. Connect and open WordPress

Import the generated `.ovpn` file into an OpenVPN client and connect. Then:

```bash
terraform -chdir=terraform/ec2 output -raw wordpress_url
```

Open that private URL in the browser. If your public IP changes, update the
trusted `/32` value in Terraform and `group_vars/vpn_servers.yml`, then apply
networking and rerun Ansible.

References: [OpenVPN 2.6 manual](https://openvpn.net/community-docs/community-articles/openvpn-2-6-manual.html),
[AWS security-group rules](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html),
and [Ansible roles](https://docs.ansible.com/projects/ansible-core/stable-2.21/playbook_guide/playbooks_reuse_roles.html).
