variable "vnet_cidr_blocks" {
  description = "CIDR blocks for virtual networks"
  type        = list(string)
  default     = ["10.0.0.0/16", "10.1.0.0/16", "10.2.0.0/16"]
}

variable "subnet_prefixes" {
  description = "Address prefixes for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "nsg_names" {
  description = "Names for network security groups"
  type        = list(string)
  default     = ["web", "app", "db"]
}

variable "nsg_ports" {
  description = "Ports for network security groups"
  type        = list(number)
  default     = [80, 8080, 3306]
}