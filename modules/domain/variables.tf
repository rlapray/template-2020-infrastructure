variable "environment" {
  description = "The environment"
}

variable "network" {
  description = "Network module"
}

variable certificate_arn {
  description = "SSL Certificate arn"
}

variable "route53_zone_id" {
  description = "Route 53 zone id found in the interface"
}

variable "subdomain" {
  description = "Subdomain to access the cluster ALB"
}