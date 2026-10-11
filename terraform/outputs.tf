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

output "vpc_id" {
  description = "ID of the dedicated VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets in both Availability Zones."
  value       = aws_subnet.public[*].id
}

output "wordpress_url" {
  description = "URL of the initialized WordPress site."
  value       = "http://${aws_eip.instance.public_ip}"
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
