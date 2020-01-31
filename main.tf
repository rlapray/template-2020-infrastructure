/*
terraform {
  backend "remote" {
    organization = "eat20"
    workspaces {
      name = "eternal"
    }
  }
}
*/

/*******************************************************************************
********** Providers
*******************************************************************************/

provider "aws" {
  region = var.region
  //access_key = var.access_key
  //secret_key = var.secret_key
  version = "~> 2.47"
}

provider "random" {
  version = "~> 2.2"
}

provider "template" {
  version = "~> 2.1"
}

provider "github" {
  token   = var.github_token
  version = "~> 2.3"
}

/*******************************************************************************
********** Networks
*******************************************************************************/

module "staging_network" {

  /*** Variables **************************************************************/
  cheap_nat = true
  enabled   = true
  /****************************************************************************/

  source               = "./modules/network_env"
  environment          = "staging"
  vpc_cidr             = var.vpc_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr

  region             = var.region
  availability_zones = var.availability_zones
}


module "production_network" {

  /*** Variables **************************************************************/
  cheap_nat = true
  enabled   = true
  /****************************************************************************/

  source               = "./modules/network_env"
  environment          = "production"
  vpc_cidr             = var.vpc_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr

  region             = var.region
  availability_zones = var.availability_zones


}

/*******************************************************************************
********** General pipeline
*******************************************************************************/

module "pipeline" {

  /*** Variables **************************************************************/
  source_bucket_name    = "eat20-sources"
  cache_bucket_name     = "eat20-cache"
  terraform_bucket_name = "eat20-terraform"
  /****************************************************************************/

  source = "./modules/pipeline"
}

/*******************************************************************************
********** Roles
*******************************************************************************/

module "staging_cluster_roles" {
  source      = "./modules/cluster_roles"
  environment = "staging"
}

module "production_cluster_roles" {
  source      = "./modules/cluster_roles"
  environment = "production"
}

module "staging_deploy_roles" {
  source      = "./modules/deploy_roles"
  environment = "staging"
}


module "production_deploy_roles" {
  source      = "./modules/deploy_roles"
  environment = "production"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

/*******************************************************************************
********** Domains
*******************************************************************************/

module "domain_staging" {
  source          = "./modules/domain"
  subdomain       = var.staging_subdomain
  certificate_arn = var.staging_certificate_arn
  route53_zone_id = var.route53_zone_id

  environment = "staging"
  network     = module.staging_network
}

module "domain_production" {
  source          = "./modules/domain"
  subdomain       = var.production_subdomain
  certificate_arn = var.production_certificate_arn
  route53_zone_id = var.route53_zone_id

  environment = "production"
  network     = module.production_network
}

/*******************************************************************************
********** Clusters
*******************************************************************************/
module "staging_cluster" {
  source      = "./modules/cluster_env"
  environment = "staging"
  network     = module.staging_network
  roles       = module.staging_deploy_roles
}

module "production_cluster" {
  source      = "./modules/cluster_env"
  environment = "production"
  network     = module.production_network
  roles       = module.staging_deploy_roles
}
/*******************************************************************************
********** Services
*******************************************************************************/
module "tpl-2020-service" {
  source        = "./services/template-2020-service"
  region        = var.region
  base_pipeline = module.pipeline
  github_token  = var.github_token


  staging_deploy_roles  = module.staging_deploy_roles
  staging_cluster_roles = module.staging_cluster_roles
  staging_domain        = module.domain_staging
  staging_cluster       = module.staging_cluster
  staging_network       = module.staging_network

  production_deploy_roles  = module.production_deploy_roles
  production_cluster_roles = module.production_cluster_roles
  production_domain        = module.domain_production
  production_cluster       = module.production_cluster
  production_network       = module.production_network
}

module "other-name" {
  source        = "./services/template-2020-service-other-name"
  region        = var.region
  base_pipeline = module.pipeline
  github_token  = var.github_token


  staging_deploy_roles  = module.staging_deploy_roles
  staging_cluster_roles = module.staging_cluster_roles
  staging_domain        = module.domain_staging
  staging_cluster       = module.staging_cluster
  staging_network       = module.staging_network

  production_deploy_roles  = module.production_deploy_roles
  production_cluster_roles = module.production_cluster_roles
  production_domain        = module.domain_production
  production_cluster       = module.production_cluster
  production_network       = module.production_network
}

module "tpl-2020-function" {
  source        = "./functions/template-2020-function"
  region        = var.region
  base_pipeline = module.pipeline
  github_token  = var.github_token


  staging_deploy_roles  = module.staging_deploy_roles
  staging_cluster_roles = module.staging_cluster_roles
  staging_domain        = module.domain_staging
  staging_network       = module.staging_network

  production_deploy_roles  = module.production_deploy_roles
  production_cluster_roles = module.production_cluster_roles
  production_domain        = module.domain_production
  production_network       = module.production_network
}