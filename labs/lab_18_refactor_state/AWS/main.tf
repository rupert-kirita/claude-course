# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.prefix}-vpc"
    Environment = var.environment
    Lab         = var.lab_name
  }
}

# Subnet
resource "aws_subnet" "app" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr

  tags = {
    Name        = "${var.prefix}-subnet"
    Environment = var.environment
    Lab         = var.lab_name
  }
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.prefix}-rt"
    Environment = var.environment
    Lab         = var.lab_name
  }
}

# Security Group
resource "aws_security_group" "web" {
  name        = "${var.prefix}-web-sg"
  description = "Lab security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.prefix}-web-sg"
    Environment = var.environment
    Lab         = var.lab_name
  }
}
