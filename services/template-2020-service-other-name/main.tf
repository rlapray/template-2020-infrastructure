variable region {}
variable base_pipeline {}
variable github_token {}

variable staging_deploy_roles {}
variable staging_cluster_roles {}
variable staging_domain {}
variable staging_cluster {}
variable staging_network {}

variable production_deploy_roles {}
variable production_cluster_roles {}
variable production_domain {}
variable production_cluster {}
variable production_network {}

locals {
  service_name        = "other-name"
  reacheable_services = ["tpl-2020-service"]
  staging_enabled     = true
  production_enabled  = true
  sql_enabled         = true
}

/*******************************************************************************
********** Service pipeline
*******************************************************************************/

module "pipeline" {

  /*** Variables **************************************************************/
  git_repository = "template-2020-service"
  git_owner      = "rlapray"
  branch         = "other-name"
  build_timeout  = 5
  log_retention  = 30
  /****************************************************************************/

  source       = "../../modules/service_pipeline"
  service_name = local.service_name
  pipeline     = var.base_pipeline
  repository   = aws_ecr_repository.repository
  region       = var.region
  github_token = var.github_token
  sql_enabled  = local.sql_enabled

  staging_enabled             = local.staging_enabled
  staging_deployment_strategy = module.staging.deployment_strategy

  production_enabled             = local.production_enabled
  production_deployment_strategy = module.production.deployment_strategy
}

/*******************************************************************************
********** Docker repository
*******************************************************************************/

resource "aws_ecr_repository" "repository" {
  name                 = local.service_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

/*******************************************************************************
********** Staging environment
*******************************************************************************/

module "staging" {

  /*** Variables **************************************************************/
  min_count        = 1
  max_count        = 2
  termination_wait = 0
  log_retention    = 90
  /****************************************************************************/

  source       = "../../modules/service_env"
  enabled      = local.staging_enabled
  service_name = local.service_name
  environment  = "staging"
  region       = var.region
  repository   = aws_ecr_repository.repository

  network       = var.staging_network
  cluster       = var.staging_cluster
  cluster_roles = var.staging_cluster_roles
  domain        = var.staging_domain

  deploy_roles = var.staging_deploy_roles

  reacheable_services = local.reacheable_services
}

output staging_mesh { value = module.staging.mesh }

/*******************************************************************************
********** Production environment
*******************************************************************************/

module "production" {

  /*** Variables **************************************************************/
  min_count        = 1
  max_count        = 2
  termination_wait = 15
  log_retention    = 90
  /****************************************************************************/

  source       = "../../modules/service_env"
  enabled      = local.production_enabled
  service_name = local.service_name
  environment  = "production"
  region       = var.region
  repository   = aws_ecr_repository.repository

  network       = var.production_network
  cluster       = var.production_cluster
  cluster_roles = var.production_cluster_roles
  domain        = var.production_domain

  deploy_roles = var.production_deploy_roles

  reacheable_services = local.reacheable_services
}

output production_mesh { value = module.production.mesh }


/*******************************************************************************
********** Middlewares => SQL
*******************************************************************************/

module "staging_database" {

  /*** Variables **************************************************************/
  backup_retention_period = 1
  min_capacity            = 2
  max_capacity            = 2
  apply_immediately       = true
  auto_pause              = true
  deletion_protection     = false
  skip_final_snapshot     = true
  /****************************************************************************/

  source = "../../modules/sql_env"

  enabled      = local.staging_enabled && local.sql_enabled
  environment  = "staging"
  network      = var.staging_network
  service_name = local.service_name
}

module "production_database" {

  /*** Variables **************************************************************/
  backup_retention_period = 1
  min_capacity            = 2
  max_capacity            = 2
  apply_immediately       = false
  auto_pause              = false
  deletion_protection     = true
  skip_final_snapshot     = false
  /***************************************************************************/

  source = "../../modules/sql_env"

  enabled      = local.production_enabled && local.sql_enabled
  environment  = "production"
  network      = var.production_network
  service_name = local.service_name
}


