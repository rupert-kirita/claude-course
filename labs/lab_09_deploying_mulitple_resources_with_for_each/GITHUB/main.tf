# Repositories created with count
resource "github_repository" "repo_count" {
  count       = 3
  name        = "repo-count-${count.index + 1}"
  description = "Repository ${count.index + 1} created with count"
  visibility  = "public"
  auto_init   = true

  topics = ["terraform", "count", "example"]
}

# Branch protection rules created with count
resource "github_branch_protection" "protection_count" {
  count         = 3
  repository_id = github_repository.repo_count[count.index].node_id
  pattern       = "main"

  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true
}

# Issue labels created with count
resource "github_issue_label" "label_count" {
  count       = 6 # 2 labels for each of 3 repos
  repository  = github_repository.repo_count[count.index % 3].name
  name        = count.index < 3 ? "bug" : "feature"
  color       = count.index < 3 ? "FF0000" : "00FF00"
  description = count.index < 3 ? "Bug issues" : "Feature requests"
}