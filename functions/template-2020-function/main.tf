variable region {}
variable base_pipeline {}
variable github_token {}

variable staging_deploy_roles {}
variable staging_cluster_roles {}
variable staging_domain {}
variable staging_network {}

variable production_deploy_roles {}
variable production_cluster_roles {}
variable production_domain {}
variable production_network {}


locals {
  function_name       = "tpl-2020-function"
  reacheable_services = []
  staging_enabled     = true
  production_enabled  = true
  sql_enabled         = false
}


module "pipeline" {

  /*** Variables **************************************************************/
  git_owner      = "rlapray"
  git_repository = "template-2020-function"
  branch         = "master"
  build_timeout  = 5
  log_retention  = 90
  /****************************************************************************/

  source        = "../../modules/function_pipeline"
  function_name = local.function_name
  pipeline      = var.base_pipeline
  region        = var.region
  github_token  = var.github_token
  sql_enabled   = local.sql_enabled

  staging_enabled      = local.staging_enabled
  staging_alb_listener = var.staging_domain.alb_listener_https

  production_enabled      = local.production_enabled
  production_alb_listener = var.production_domain.alb_listener_https
}