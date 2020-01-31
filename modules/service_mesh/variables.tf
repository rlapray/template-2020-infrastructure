variable service_name {
}

variable environment {
}

variable cluster {
}

variable reacheable_services {
  type        = list(string)
  description = "Other services in this mesh and environment reachable by this service"
}