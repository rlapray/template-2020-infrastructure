/*******************************************************************************
********** Cluster
*******************************************************************************/

locals {
  cluster_name  = "${var.environment}-${replace(var.service_name, "_", "-")}"
  database_name = replace(var.service_name, "-", "_")
  user_name     = "master_user"
}


resource aws_rds_cluster "postgres" {
  count              = var.enabled ? 1 : 0
  cluster_identifier = local.cluster_name
  engine             = "aurora-postgresql"
  engine_version     = "10.7"
  engine_mode        = "serverless"
  database_name      = local.database_name
  master_username    = local.user_name
  master_password    = random_password.password[0].result

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "00:00-05:30"
  preferred_maintenance_window = "sun:05:30-sun:06:00"
  apply_immediately            = var.apply_immediately

  scaling_configuration {
    auto_pause     = var.auto_pause
    min_capacity   = var.min_capacity
    max_capacity   = var.max_capacity
    timeout_action = "ForceApplyCapacityChange"
  }

  db_subnet_group_name            = aws_db_subnet_group.db_subnet_group[0].name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.default[0].id
  vpc_security_group_ids          = [aws_security_group.default[0].id]

  copy_tags_to_snapshot     = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${var.environment}-${replace(var.service_name, "_", "-")}"

  lifecycle {
    create_before_destroy = false
  }

  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}

/*******************************************************************************
********** Cluster configuration
*******************************************************************************/


resource "aws_db_subnet_group" "db_subnet_group" {
  count       = var.enabled ? 1 : 0
  name        = "dbsub-${var.environment}-${replace(var.service_name, "_", "-")}"
  description = "Group of DB subnets"
  subnet_ids  = var.network.private_subnets_id

  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}

resource "aws_rds_cluster_parameter_group" "default" {
  count  = var.enabled ? 1 : 0
  name   = "pg-${var.environment}-${replace(var.service_name, "_", "-")}"
  family = "aurora-postgresql10"

  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}

/*******************************************************************************
********** Security Group
*******************************************************************************/

resource "aws_security_group" "default" {
  count       = var.enabled ? 1 : 0
  name        = "secgrp-psql-${var.environment}"
  description = "Allow TCP 5432 from Anywhere"
  vpc_id      = var.network.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.network.private_subnets_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.network.private_subnets_cidrs
  }

  tags = {
    Name        = "secgrp-psql-${var.environment}-${replace(var.service_name, "_", "-")}"
    Service     = var.service_name
    Environment = var.environment
  }
}

/*******************************************************************************
********** Database access
*******************************************************************************/

resource "random_password" "password" {
  count            = var.enabled ? 1 : 0
  length           = 16
  special          = true
  min_special      = 4
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "cluster" {
  count       = var.enabled ? 1 : 0
  name        = "${var.environment}.${var.service_name}.sql.cluster.url"
  type        = "String"
  value       = aws_rds_cluster.postgres[0].endpoint
  description = "Cluster url for the '${var.service_name}' service in the ${var.environment} environment"

  tags = {
    Environment = "${var.environment}"
    Service     = var.service_name
  }
}

resource "aws_ssm_parameter" "database" {
  count       = var.enabled ? 1 : 0
  name        = "${var.environment}.${var.service_name}.sql.database"
  type        = "String"
  value       = local.database_name
  description = "Database name for the '${var.service_name}' service in the ${var.environment} environment"

  tags = {
    Environment = "${var.environment}"
    Service     = var.service_name
  }
}

resource "aws_ssm_parameter" "user" {
  count       = var.enabled ? 1 : 0
  name        = "${var.environment}.${var.service_name}.sql.user"
  type        = "String"
  value       = local.user_name
  description = "master_username for the '${var.service_name}' service database in the ${var.environment} environment"

  tags = {
    Environment = "${var.environment}"
    Service     = var.service_name
  }
}

resource "aws_ssm_parameter" "password" {
  count       = var.enabled ? 1 : 0
  name        = "${var.environment}.${var.service_name}.sql.password"
  type        = "SecureString"
  value       = random_password.password[0].result
  description = "master_username password for the '${var.service_name}' service database in the ${var.environment} environment"

  tags = {
    Environment = "${var.environment}"
    Service     = var.service_name
  }
}