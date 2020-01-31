/*
variable "access_key" {
}
variable "secret_key" {
}
*/
variable "region" {
  default = "eu-west-1"
}
variable "availability_zones" {
  type        = list(string)
  description = "The az that the resources will be launched"
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "route53_zone_id" {
  type        = string
  description = "Zone id of your domain"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets_cidr" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "staging_subdomain" {
  type = string
}

variable "staging_certificate_arn" {
  type = string
}

variable "production_subdomain" {
  type = string
}

variable "production_certificate_arn" {
  type = string
}

variable "github_token" {
  type = string
}