variable "aws_region" {
  description = "AWS region where the network will be created."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Name of the local AWS CLI profile. This is not a credential."
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Name used to tag and identify networking resources."
  type        = string
  default     = "wordpress-host"
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

variable "vpn_private_ip" {
  description = "Fixed private IPv4 address assigned to the OpenVPN instance."
  type        = string
  default     = "10.20.1.10"

  validation {
    condition = (
      can(cidrhost("${var.vpn_private_ip}/${split("/", var.public_subnet_cidrs[0])[1]}", 0)) &&
      cidrhost("${var.vpn_private_ip}/${split("/", var.public_subnet_cidrs[0])[1]}", 0) == cidrhost(var.public_subnet_cidrs[0], 0)
    )
    error_message = "The OpenVPN private IP must be a valid host address inside the first public subnet."
  }
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to use SSH. Leave empty to keep port 22 closed."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.ssh_allowed_cidrs :
      can(cidrhost(cidr, 0)) && cidr != "0.0.0.0/0"
    ])
    error_message = "SSH CIDRs must be valid and must not contain 0.0.0.0/0."
  }
}

variable "vpn_allowed_cidrs" {
  description = "Trusted public CIDR blocks allowed to initiate OpenVPN connections."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.vpn_allowed_cidrs :
      can(cidrhost(cidr, 0)) && cidr != "0.0.0.0/0"
    ])
    error_message = "OpenVPN CIDRs must be valid and must not contain 0.0.0.0/0."
  }
}

variable "vpn_port" {
  description = "UDP port used by the OpenVPN server."
  type        = number
  default     = 1194

  validation {
    condition     = var.vpn_port >= 1 && var.vpn_port <= 65535
    error_message = "The OpenVPN port must be between 1 and 65535."
  }
}
