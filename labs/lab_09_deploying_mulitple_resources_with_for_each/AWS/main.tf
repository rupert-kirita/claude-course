# Main VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Subnets created with count
resource "aws_subnet" "subnet" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_blocks[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "subnet-${count.index + 1}"
    Tier = count.index < 1 ? "public" : "private"
  }
}

# Security groups created with count
resource "aws_security_group" "sg" {
  count       = 3
  name        = "${var.security_groups[count.index]}-sg"
  description = "Security group for ${var.security_groups[count.index]}"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.security_groups[count.index]}-sg"
  }
}

# Security group rules created with count
resource "aws_security_group_rule" "ingress" {
  count             = 3
  type              = "ingress"
  from_port         = var.sg_ports[count.index]
  to_port           = var.sg_ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg[count.index].id
}