locals {
  virtual_service_name = "${var.service_name}.${var.environment}.local"
}

resource "aws_service_discovery_service" "registry" {
  name = var.service_name

  dns_config {
    namespace_id = var.cluster.service_discovery_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_appmesh_virtual_service" "service" {
  name      = local.virtual_service_name
  mesh_name = var.cluster.mesh.id

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.router.name
      }
    }
  }

  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}

resource "aws_appmesh_virtual_node" "node" {
  name      = var.service_name
  mesh_name = var.cluster.mesh.id

  spec {
    dynamic "backend" {
      for_each = var.reacheable_services
      content {
        virtual_service {
          virtual_service_name = "${backend.value}.${var.environment}.local"
        }
      }
    }

    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
      health_check {
        protocol            = "http"
        path                = "/${var.service_name}/public/healthcheck"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout_millis      = 2000
        interval_millis     = 5000
      }
    }

    service_discovery {
      dns {
        hostname = "${var.service_name}.${var.environment}.local"
      }
    }
  }
  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}

resource "aws_appmesh_virtual_router" "router" {
  name      = var.service_name
  mesh_name = var.cluster.mesh.id

  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
    }
  }
}

resource "aws_appmesh_route" "route" {
  name                = "${var.service_name}-route"
  mesh_name           = var.cluster.mesh.id
  virtual_router_name = aws_appmesh_virtual_router.router.name

  spec {
    http_route {

      match {
        prefix = "/${var.service_name}/"
      }

      action {
        weighted_target {
          virtual_node = aws_appmesh_virtual_node.node.name
          weight       = 100
        }

      }
    }
  }
  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}