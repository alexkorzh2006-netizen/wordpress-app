variable "aws_region" {
  description = "AWS region where the EC2 instance will be created."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Name of the local AWS CLI profile. This is not a credential."
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Name used to tag and identify EC2 resources."
  type        = string
  default     = "wordpress-host"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Optional name of an existing AWS EC2 key pair."
  type        = string
  default     = null
  nullable    = true
}

variable "networking_state_path" {
  description = "Path to the state produced by the networking configuration."
  type        = string
  default     = "../networking/terraform.tfstate"
}

variable "wordpress_site_title" {
  description = "Title assigned during the automatic WordPress installation."
  type        = string
  default     = "Test WordPress"
}

variable "wordpress_admin_user" {
  description = "WordPress administrator username."
  type        = string
  default     = "wpadmin"
}

variable "wordpress_admin_email" {
  description = "WordPress administrator email address."
  type        = string
  default     = "admin@example.com"
}

