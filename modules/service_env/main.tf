module "task" {
  source        = "../service_task"
  environment   = var.environment
  image         = var.repository.repository_url
  service_name  = var.service_name
  min_count     = var.enabled ? var.min_count : 0
  max_count     = var.enabled ? var.max_count : 0
  log_retention = var.log_retention

  region = var.region

  cluster_roles = var.cluster_roles
  network       = var.network
  cluster       = var.cluster
  domain        = var.domain
  mesh          = module.mesh
}

module "deployment_strategy" {
  source             = "../service_deploy"
  environment        = var.environment
  cluster            = var.cluster
  service_name       = var.service_name
  target_group_blue  = module.task.target_group_blue
  target_group_green = module.task.target_group_green
  deploy_role        = var.deploy_roles.deploy_role
  domain             = var.domain
  service            = module.task
  termination_wait   = var.termination_wait
}

module "mesh" {
  source              = "../service_mesh"
  environment         = var.environment
  cluster             = var.cluster
  service_name        = var.service_name
  reacheable_services = var.reacheable_services
}