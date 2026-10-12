output "vpc_id" {
  description = "ID of the dedicated VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets in both Availability Zones."
  value       = aws_subnet.public[*].id
}

output "security_group_id" {
  description = "ID of the security group for the EC2 instance."
  value       = aws_security_group.instance.id
}

output "vpn_port" {
  description = "UDP port allowed for OpenVPN."
  value       = var.vpn_port
}
