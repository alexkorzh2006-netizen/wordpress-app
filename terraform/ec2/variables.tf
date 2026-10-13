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
  description = "EC2 instance type for WordPress and MariaDB."
  type        = string
  default     = "t3.small"
}

variable "vpn_instance_type" {
  description = "EC2 instance type for the OpenVPN gateway."
  type        = string
  default     = "t3.micro"
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

variable "wordpress_domain" {
  description = "Fully qualified Cloudflare DNS name used for WordPress and its TLS certificate."
  type        = string

  validation {
    condition = length(split(".", var.wordpress_domain)) >= 2 && alltrue([
      for label in split(".", var.wordpress_domain) :
      can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", label))
    ])
    error_message = "wordpress_domain must be a fully qualified domain name such as wordpress.example.com."
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID containing wordpress_domain. This identifier is not an API credential."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{32}$", var.cloudflare_zone_id))
    error_message = "cloudflare_zone_id must be the 32-character Zone ID from Cloudflare."
  }
}

variable "certificate_email" {
  description = "Email address registered with Let's Encrypt for certificate notices."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.certificate_email))
    error_message = "certificate_email must be a valid email address."
  }
}

