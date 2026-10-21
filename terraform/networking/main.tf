data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-public-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "vpn" {
  name_prefix = "${var.project_name}-vpn-"
  description = "Public entry point for SSH and OpenVPN"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-vpn-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "openvpn" {
  for_each = var.vpn_allowed_cidrs

  security_group_id = aws_security_group.vpn.id
  description       = "OpenVPN from an approved network"
  cidr_ipv4         = each.value
  from_port         = var.vpn_port
  to_port           = var.vpn_port
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = var.ssh_allowed_cidrs

  security_group_id = aws_security_group.vpn.id
  description       = "SSH from an approved network"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "vpn_all" {
  security_group_id = aws_security_group.vpn.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "wordpress" {
  name_prefix = "${var.project_name}-wordpress-"
  description = "WordPress access from the OpenVPN gateway only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-wordpress-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "wordpress_http_from_vpn" {
  security_group_id = aws_security_group.wordpress.id
  description       = "HTTP from the OpenVPN gateway"
  cidr_ipv4         = "${var.vpn_private_ip}/32"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "wordpress_https_from_vpn" {
  security_group_id = aws_security_group.wordpress.id
  description       = "HTTPS from the OpenVPN gateway"
  cidr_ipv4         = "${var.vpn_private_ip}/32"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "wordpress_ssh_from_vpn" {
  security_group_id = aws_security_group.wordpress.id
  description       = "SSH from the OpenVPN gateway"
  cidr_ipv4         = "${var.vpn_private_ip}/32"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "wordpress_all" {
  security_group_id = aws_security_group.wordpress.id
  description       = "Allow outbound updates and package downloads"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
