variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}