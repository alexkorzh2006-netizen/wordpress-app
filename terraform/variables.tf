variable "aws_region" {
  description = "AWS region where the infrastructure will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to tag and identify the resources."
  type        = string
  default     = "wordpress-host"
}

variable "instance_type" {
  description = "EC2 instance type. t3.small provides 2 GiB RAM for a small WordPress installation."
  type        = string
  default     = "t3.small"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the dedicated VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "IPv4 CIDR blocks for public subnets in two Availability Zones."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs must be provided."
  }
}

variable "key_name" {
  description = "Optional name of an existing AWS EC2 key pair."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to use SSH. Leave empty to keep port 22 closed."
  type        = set(string)
  default     = []
}

variable "wordpress_site_title" {
  description = "Title assigned during the automatic WordPress installation."
  type        = string
  default     = "Test WordPress"
}

variable "wordpress_admin_user" {
  description = "Administrator username created by WP-CLI."
  type        = string
  default     = "wpadmin"
}

variable "wordpress_admin_email" {
  description = "Administrator email address created by WP-CLI."
  type        = string
  default     = "admin@example.com"
}
