terraform {
  required_version = ">= 1.12.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Primary region provider
provider "aws" {
  region = var.primary_region
  alias  = "primary"
}

# Secondary region provider
provider "aws" {
  region = var.secondary_region
  alias  = "secondary"
}