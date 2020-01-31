/*******************************************************************************
********** ECS Cluster
*******************************************************************************/
resource "aws_ecs_cluster" "cluster" {
  name = var.environment

  depends_on = [var.roles]

  tags = {
    Environment = var.environment
  }
}

/*******************************************************************************
********** Security Group
*******************************************************************************/

resource "aws_security_group" "ecs_service" {
  vpc_id      = var.network.vpc_id
  name        = "secgrp-${var.environment}-ecs"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "secgrp-${var.environment}-ecs"
    Environment = var.environment
  }
}

/*******************************************************************************
********** AppMesh
*******************************************************************************/

resource "aws_appmesh_mesh" "mesh" {
  name = var.environment
}

resource "aws_service_discovery_private_dns_namespace" "default" {
  name = "${var.environment}.local"
  vpc  = var.network.vpc_id
}