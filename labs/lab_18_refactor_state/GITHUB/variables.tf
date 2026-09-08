variable "repository_name" {
  description = "Name of the lab repository"
  type        = string
  default     = "lab-refactor-repo"
}

variable "repository_description" {
  description = "Description for the lab repository"
  type        = string
  default     = "Lab repository for state refactoring"
}

variable "repository_visibility" {
  description = "Visibility of the repository (public or private)"
  type        = string
  default     = "public"
}

variable "config_file_path" {
  description = "Path of the managed file within the repository"
  type        = string
  default     = "config/app.txt"
}

variable "config_file_content" {
  description = "Contents of the managed file"
  type        = string
  default     = "Managed by Terraform"
}

variable "legacy_label_name" {
  description = "Name of the legacy issue label"
  type        = string
  default     = "legacy"
}

variable "legacy_label_color" {
  description = "Color of the legacy issue label (hex, no #)"
  type        = string
  default     = "d73a4a"
}

variable "app_label_name" {
  description = "Name of the application issue label"
  type        = string
  default     = "lab-label"
}

variable "app_label_color" {
  description = "Color of the application issue label (hex, no #)"
  type        = string
  default     = "0e8a16"
}
