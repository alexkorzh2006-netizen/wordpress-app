output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Stable public Elastic IP address of the EC2 instance."
  value       = aws_eip.instance.public_ip
}

output "private_ip" {
  description = "Private IPv4 address of the EC2 instance."
  value       = aws_instance.web.private_ip
}

output "wordpress_url" {
  description = "Private WordPress URL, reachable from the VPC or OpenVPN tunnel."
  value       = "http://${aws_instance.web.private_ip}"
}

output "openvpn_endpoint" {
  description = "Stable public endpoint used by OpenVPN clients."
  value       = "${aws_eip.instance.public_ip}:${data.terraform_remote_state.networking.outputs.vpn_port}"
}

output "wordpress_admin_user" {
  description = "WordPress administrator username."
  value       = var.wordpress_admin_user
}

output "wordpress_admin_password" {
  description = "Generated WordPress administrator password."
  value       = random_password.wordpress_admin.result
  sensitive   = true
}

