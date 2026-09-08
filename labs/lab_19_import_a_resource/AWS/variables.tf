variable "aws_region" {
  description = "AWS region where the Lab 18 resources live"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "lab"
}

variable "environment" {
  description = "Environment name for tagging (must match the existing resources)"
  type        = string
  default     = "dev"
}

variable "lab_name" {
  description = "Lab identifier for tagging (the existing resources were tagged by Lab 18)"
  type        = string
  default     = "lab18"
}

variable "vpc_cidr" {
  description = "CIDR block of the existing VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block of the existing subnet"
  type        = string
  default     = "10.0.1.0/24"
}
