variable "azure_location" {
  description = "Azure region where the Lab 18 resources live"
  type        = string
  default     = "eastus"
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

variable "vnet_cidr" {
  description = "Address space of the existing virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Address prefix of the existing subnet"
  type        = string
  default     = "10.0.1.0/24"
}
