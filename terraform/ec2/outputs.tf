output "wordpress_instance_id" {
  description = "ID of the WordPress and MariaDB EC2 instance."
  value       = aws_instance.wordpress.id
}

output "wordpress_private_ip" {
  description = "Private IPv4 address of the WordPress and MariaDB instance."
  value       = aws_instance.wordpress.private_ip
}

output "vpn_instance_id" {
  description = "ID of the OpenVPN EC2 instance."
  value       = aws_instance.openvpn.id
}

output "vpn_public_ip" {
  description = "Stable public Elastic IP address of the OpenVPN instance."
  value       = aws_eip.openvpn.public_ip
}

output "vpn_private_ip" {
  description = "Private IPv4 address of the OpenVPN instance."
  value       = aws_instance.openvpn.private_ip
}

output "wordpress_url" {
  description = "HTTPS WordPress URL, reachable after connecting to OpenVPN."
  value       = "https://${var.wordpress_domain}"
}

output "wordpress_private_url" {
  description = "Private-IP URL used before DNS and TLS configuration finishes."
  value       = "http://${aws_instance.wordpress.private_ip}"
}

output "wordpress_domain" {
  description = "Cloudflare DNS name used by WordPress and Certbot."
  value       = var.wordpress_domain
}

output "wordpress_certificate_email" {
  description = "Email address registered with the ACME certificate authority."
  value       = var.certificate_email
}

output "openvpn_endpoint" {
  description = "Stable public endpoint used by OpenVPN clients."
  value       = "${aws_eip.openvpn.public_ip}:${data.terraform_remote_state.networking.outputs.vpn_port}"
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

