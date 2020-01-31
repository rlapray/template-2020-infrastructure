variable "function_name" {
  description = "Function name"
}

variable "git_repository" {
  type        = string
  description = "Git repository"
}

variable "git_owner" {
  type        = string
  description = "Git repository owner"
}

variable "region" {
  description = "Region name"
}

variable "pipeline" {
  description = "Pipeline module"
}

variable staging_enabled {
  type        = bool
  description = "When false, destroy anything pricey"
}

variable production_enabled {
  type        = bool
  description = "When false, destroy anything pricey"
}

variable sql_enabled {
}

variable branch {
}

variable build_timeout {
}

variable github_token {
}

variable log_retention {
}

variable staging_alb_listener {
}

variable production_alb_listener {
}