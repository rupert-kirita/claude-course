# Base Repository
resource "github_repository" "main" {
  name        = "terraform-${var.environment}-repo"
  description = "Terraform managed ${var.environment} repository"
  visibility  = var.repo_visibility
  auto_init   = true

  topics = ["terraform", "depends-on-demo"]
}

# Repository File
resource "github_repository_file" "readme" {
  repository          = github_repository.main.name
  branch              = var.default_branch
  file                = "README.md"
  content             = "# Terraform ${var.environment} Repository\n\nManaged by Terraform."
  commit_message      = "Add README"
  commit_author       = "Terraform"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

# Issue Label
resource "github_issue_label" "bug" {
  repository  = github_repository.main.name
  name        = "bug"
  color       = "FF0000"
  description = "Bug reports"
}