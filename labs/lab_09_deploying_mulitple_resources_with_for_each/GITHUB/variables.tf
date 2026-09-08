variable "repo_names" {
  description = "Names for repositories"
  type        = list(string)
  default     = ["repo-1", "repo-2", "repo-3"]
}

variable "label_names" {
  description = "Names for issue labels"
  type        = list(string)
  default     = ["bug", "feature"]
}

variable "label_colors" {
  description = "Colors for issue labels"
  type        = list(string)
  default     = ["FF0000", "00FF00"]
}