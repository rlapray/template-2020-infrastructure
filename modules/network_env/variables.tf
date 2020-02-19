variable "vpc_cidr" {
  description = "The CIDR block of the vpc"
}

variable "public_subnets_cidr" {
  type        = list(string)
  description = "The CIDR block for the public subnet"
}

variable "private_subnets_cidr" {
  type        = list(string)
  description = "The CIDR block for the private subnet"
}

variable "environment" {
  description = "The environment"
  default     = "staging"
}

variable "region" {
  description = "The region to launch the bastion host"
}

variable "availability_zones" {
  type        = list(string)
  description = "The az that the resources will be launched"
}

variable cheap_nat {
  type        = bool
  description = "If true, nat gateways will be replace by one nano nat instance"
}

variable enabled {
  type        = bool
  description = "When false, destroy anything pricey"
}