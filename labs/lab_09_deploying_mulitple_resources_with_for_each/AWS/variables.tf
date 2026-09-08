variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "subnet_cidr_blocks" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "security_groups" {
  description = "Security group names"
  type        = list(string)
  default     = ["web", "app", "db"]
}

variable "sg_ports" {
  description = "Ports for security group rules"
  type        = list(number)
  default     = [80, 8080, 3306]
}