# Standard repository without lifecycle configuration
resource "github_repository" "standard" {
  name        = "standard-${var.environment}-repo"
  description = "Standard repository for ${var.environment} environment"
  visibility  = var.repo_visibility
  auto_init   = true

  topics = ["terraform", "lifecycle-demo"]
}

# Issue label without lifecycle configuration
resource "github_issue_label" "standard" {
  repository  = github_repository.standard.name
  name        = "standard"
  color       = "FF0000"
  description = "Standard issue label"
}