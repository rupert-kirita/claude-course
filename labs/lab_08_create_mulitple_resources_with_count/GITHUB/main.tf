# Individual Repository Resources
resource "github_repository" "repo1" {
  name        = "example-repo-1"
  description = "Example repository 1"
  visibility  = "public"
  auto_init   = true

  topics = ["example", "terraform", "repo1"]
}

resource "github_repository" "repo2" {
  name        = "example-repo-2"
  description = "Example repository 2"
  visibility  = "public"
  auto_init   = true

  topics = ["example", "terraform", "repo2"]
}

resource "github_repository" "repo3" {
  name        = "example-repo-3"
  description = "Example repository 3"
  visibility  = "public"
  auto_init   = true

  topics = ["example", "terraform", "repo3"]
}

# Individual Branch Protection Resources
resource "github_branch_protection" "protection1" {
  repository_id = github_repository.repo1.node_id
  pattern       = "main"

  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true
}

resource "github_branch_protection" "protection2" {
  repository_id = github_repository.repo2.node_id
  pattern       = "main"

  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true
}

resource "github_branch_protection" "protection3" {
  repository_id = github_repository.repo3.node_id
  pattern       = "main"

  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true
}

# Individual Issue Label Resources
resource "github_issue_label" "bug1" {
  repository  = github_repository.repo1.name
  name        = "bug"
  color       = "FF0000"
  description = "Bug issues"
}

resource "github_issue_label" "feature1" {
  repository  = github_repository.repo1.name
  name        = "feature"
  color       = "00FF00"
  description = "Feature requests"
}

resource "github_issue_label" "bug2" {
  repository  = github_repository.repo2.name
  name        = "bug"
  color       = "FF0000"
  description = "Bug issues"
}

resource "github_issue_label" "feature2" {
  repository  = github_repository.repo2.name
  name        = "feature"
  color       = "00FF00"
  description = "Feature requests"
}