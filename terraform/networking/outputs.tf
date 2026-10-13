output "vpc_id" {
  description = "ID of the dedicated VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets in both Availability Zones."
  value       = aws_subnet.public[*].id
}

output "vpn_security_group_id" {
  description = "ID of the security group attached to the OpenVPN instance."
  value       = aws_security_group.vpn.id
}

output "wordpress_security_group_id" {
  description = "ID of the security group attached to the WordPress instance."
  value       = aws_security_group.wordpress.id
}

output "vpn_private_ip" {
  description = "Fixed private IPv4 address reserved for the OpenVPN instance."
  value       = var.vpn_private_ip
}

output "vpn_port" {
  description = "UDP port allowed for OpenVPN."
  value       = var.vpn_port
}

output "vpn_allowed_cidrs" {
  description = "Trusted public CIDRs allowed to establish OpenVPN connections."
  value       = sort(tolist(var.vpn_allowed_cidrs))
}

output "ssh_allowed_cidrs" {
  description = "Trusted public CIDRs allowed to SSH to the OpenVPN instance."
  value       = sort(tolist(var.ssh_allowed_cidrs))
}
