resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  associate_public_ip_address = false
  key_name                    = var.key_name
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    dockerfile_b64               = base64encode(file("${path.module}/../docker/Dockerfile"))
    docker_compose_b64           = base64encode(file("${path.module}/../docker/docker-compose.yml"))
    wordpress_url_b64            = base64encode("http://${aws_eip.instance.public_ip}")
    wordpress_site_title_b64     = base64encode(var.wordpress_site_title)
    wordpress_admin_user_b64     = base64encode(var.wordpress_admin_user)
    wordpress_admin_password_b64 = base64encode(random_password.wordpress_admin.result)
    wordpress_admin_email_b64    = base64encode(var.wordpress_admin_email)
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
    Name = "${var.project_name}-ec2"
  }

  depends_on = [aws_route_table_association.public]
}
