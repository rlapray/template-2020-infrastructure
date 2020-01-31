variable "service_name" {
  description = "Service name"
}

variable "git_repository" {
  type        = string
  description = "Git repository"
}

variable "region" {
  description = "Region name"
}

variable "pipeline" {
  description = "Pipeline module"
}

variable "repository" {
  description = "Service repository"
}

variable staging_enabled {
  type        = bool
  description = "When false, destroy anything pricey"
}

variable production_enabled {
  type        = bool
  description = "When false, destroy anything pricey"
}

variable staging_deployment_strategy {
}

variable production_deployment_strategy {
}

variable sql_enabled {
}

variable branch {
}

variable git_owner {
}


variable build_timeout {
}

variable github_token {
}

variable log_retention {
}
