# GitHub Repository
resource "github_repository" "main" {
  name        = var.repository_name
  description = var.repository_description
  visibility  = var.repository_visibility
  auto_init   = true
}

# Repository File
resource "github_repository_file" "config" {
  repository          = github_repository.main.name
  branch              = "main"
  file                = var.config_file_path
  content             = var.config_file_content
  commit_message      = "Add app config"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

# Legacy Issue Label
resource "github_issue_label" "legacy" {
  repository = github_repository.main.name
  name       = var.legacy_label_name
  color      = var.legacy_label_color
}

# Application Issue Label
resource "github_issue_label" "web" {
  repository = github_repository.main.name
  name       = var.app_label_name
  color      = var.app_label_color
}
