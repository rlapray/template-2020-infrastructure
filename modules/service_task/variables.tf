variable service_name {
  description = "Service name"
}

variable region {
  description = "Region name"
}

variable environment {
  description = "The environment"
}

variable min_count {
  type        = number
  description = "Minimum container count"
}

variable max_count {
  type        = number
  description = "Maximum container count"
}

variable network {
  description = "Network module"
}

variable cluster {
  description = "Cluster module"
}

variable cluster_roles {
  description = "Cluster roles module"
}

variable image {
  description = "Image used for the tasks"
}

variable domain {
  description = "Domain with alb"
}

variable mesh {
}

variable log_retention {
}
