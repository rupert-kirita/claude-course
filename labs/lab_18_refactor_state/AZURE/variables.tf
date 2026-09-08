variable "azure_location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "lab"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "dev"
}

variable "lab_name" {
  description = "Lab identifier for tagging"
  type        = string
  default     = "lab18"
}

variable "vnet_cidr" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Address prefix for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}
