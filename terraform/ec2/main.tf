data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = var.networking_state_path
  }
}

resource "random_password" "wordpress_database" {
  length  = 32
  special = false
}

resource "random_password" "wordpress_admin" {
  length  = 24
  special = false
}

resource "aws_instance" "wordpress" {
  ami                         = "ami-0fa5967347d08d2df"
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.networking.outputs.public_subnet_ids[1]
  vpc_security_group_ids      = [data.terraform_remote_state.networking.outputs.wordpress_security_group_id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    install_script_b64              = base64encode(file("${path.module}/../../scripts/install-wordpress.sh"))
    wordpress_title_b64             = base64encode(var.wordpress_site_title)
    wordpress_admin_user_b64        = base64encode(var.wordpress_admin_user)
    wordpress_admin_email_b64       = base64encode(var.wordpress_admin_email)
    wordpress_admin_password_b64    = base64encode(random_password.wordpress_admin.result)
    wordpress_database_password_b64 = base64encode(random_password.wordpress_database.result)
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-wordpress-ec2"
    Role = "wordpress"
  }
}

resource "aws_instance" "openvpn" {
  ami                         = "ami-0fa5967347d08d2df"
  instance_type               = var.vpn_instance_type
  subnet_id                   = data.terraform_remote_state.networking.outputs.public_subnet_ids[0]
  private_ip                  = data.terraform_remote_state.networking.outputs.vpn_private_ip
  vpc_security_group_ids      = [data.terraform_remote_state.networking.outputs.vpn_security_group_id]
  associate_public_ip_address = false
  source_dest_check           = false
  key_name                    = var.key_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-openvpn-ec2"
    Role = "openvpn"
  }
}

resource "aws_eip" "openvpn" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-openvpn-eip"
  }
}

resource "aws_eip_association" "openvpn" {
  allocation_id = aws_eip.openvpn.id
  instance_id   = aws_instance.openvpn.id
}

resource "cloudflare_dns_record" "wordpress" {
  zone_id = var.cloudflare_zone_id
  name    = var.wordpress_domain
  content = aws_instance.wordpress.private_ip
  type    = "A"
  ttl     = 60
  proxied = false
  comment = "Private WordPress address managed by Terraform"
}
