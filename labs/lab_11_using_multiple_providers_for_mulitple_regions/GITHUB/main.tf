# Repository for primary owner
resource "github_repository" "primary" {
  provider    = github.primary
  name        = "terraform-${var.environment}-primary"
  description = "Terraform managed repository for ${var.environment} environment"
  visibility  = var.repo_visibility
  auto_init   = true

  topics = ["terraform", "multi-provider-demo"]
}

# Repository for secondary owner
resource "github_repository" "secondary" {
  provider    = github.secondary
  name        = "terraform-${var.environment}-secondary"
  description = "Terraform managed repository for ${var.environment} environment"
  visibility  = var.repo_visibility
  auto_init   = true

  topics = ["terraform", "multi-provider-demo"]
}