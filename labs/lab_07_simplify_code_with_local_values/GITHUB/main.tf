# Static configuration with repetitive elements
resource "github_repository" "app" {
  name        = "production-application"
  description = "Production application repository"
  visibility  = "public"

  has_issues      = true
  has_wiki        = true
  has_discussions = true
  has_projects    = true

  allow_merge_commit = true
  allow_rebase_merge = true
  allow_squash_merge = true

  delete_branch_on_merge = true
  auto_init              = true

  topics = [
    "production",
    "application",
    "terraform-demo",
    "infrastructure-team"
  ]
}

resource "github_repository" "docs" {
  name        = "production-documentation"
  description = "Production documentation repository"
  visibility  = "public"

  has_issues      = true
  has_wiki        = true
  has_discussions = true
  has_projects    = true

  allow_merge_commit = true
  allow_rebase_merge = true
  allow_squash_merge = true

  delete_branch_on_merge = true
  auto_init              = true

  topics = [
    "production",
    "documentation",
    "terraform-demo",
    "infrastructure-team"
  ]
}