/*******************************************************************************
********** Cloudwatch
*******************************************************************************/

resource "aws_cloudwatch_log_group" "service" {
  name              = "/aws/ecs/taskDefinition/${var.environment}/${var.service_name}"
  retention_in_days = var.log_retention
  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}

resource "aws_cloudwatch_log_group" "envoy" {
  name              = "/aws/ecs/taskDefinition/${var.environment}/${var.service_name}/envoy"
  retention_in_days = var.log_retention
  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}


/*******************************************************************************
********** Task definition
*******************************************************************************/

/* the task definition for the web service */
data "template_file" "web_task" {
  template = file("${path.module}/web_task_definition.json")

  vars = {
    image        = var.image
    env          = var.environment
    service_name = var.service_name
    environment  = var.environment
    region       = var.region
    log_group    = aws_cloudwatch_log_group.service.name
  }
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${var.environment}-${var.service_name}"
  container_definitions    = data.template_file.web_task.rendered
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.cluster_roles.ecs_execution_role.arn
  task_role_arn            = var.cluster_roles.ecs_execution_role.arn
  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

/* Simply specify the family to find the latest ACTIVE revision in that family */
data "aws_ecs_task_definition" "web" {
  task_definition = aws_ecs_task_definition.web.family
  depends_on      = [aws_ecs_task_definition.web]
}

resource "aws_ecs_service" "web" {
  name            = var.service_name
  task_definition = "${aws_ecs_task_definition.web.family}:${max("${aws_ecs_task_definition.web.revision}", "${data.aws_ecs_task_definition.web.revision}")}"
  desired_count   = var.min_count
  launch_type     = "FARGATE"
  cluster         = var.cluster.cluster_id
  depends_on      = [var.domain, var.cluster_roles, aws_alb_target_group.blue_target_group, aws_alb_target_group.green_target_group]

  network_configuration {
    security_groups = concat(var.network.security_groups_ids, [var.cluster.ecs_service_group.id])
    subnets         = var.network.private_subnets_id
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.blue_target_group.arn
    container_name   = "web"
    container_port   = "80"
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  service_registries {
    registry_arn = var.mesh.registry.arn
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition, load_balancer]
  }
}

/*******************************************************************************
********** Auto scaling
*******************************************************************************/

resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster.cluster_name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn           = var.cluster_roles.autoscale_role.arn
  min_capacity       = var.min_count
  max_capacity       = var.max_count

  lifecycle {
    ignore_changes = [role_arn]
  }
}

resource "aws_appautoscaling_policy" "up" {
  name               = "${var.environment}/${var.service_name}/scale_up"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster.cluster_name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = [aws_appautoscaling_target.target]
}

resource "aws_appautoscaling_policy" "down" {
  name               = "${var.environment}/${var.service_name}/scale_down"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster.cluster_name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = [aws_appautoscaling_target.target]
}

/* metric used for auto scale */
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${var.environment}/${var.service_name}/cpu_utilization_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "85"

  dimensions = {
    ClusterName = var.cluster.cluster_name
    ServiceName = aws_ecs_service.web.name
  }

  alarm_actions = [aws_appautoscaling_policy.up.arn]
  ok_actions    = [aws_appautoscaling_policy.down.arn]

  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}

/*******************************************************************************
********** Target groups
*******************************************************************************/

resource "aws_alb_target_group" "blue_target_group" {
  name                 = "tg-${var.environment}-${replace(var.service_name, "_", "-")}-b"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.network.vpc_id
  target_type          = "ip"
  deregistration_delay = 60
  slow_start           = 30

  lifecycle {
    create_before_destroy = false
  }

  health_check {
    protocol = "HTTP"
    port     = "80"
    path     = "/healthcheck"
  }

  depends_on = [var.domain]

  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}

resource "aws_lb_listener_rule" "public_blue" {
  listener_arn = var.domain.alb_listener_https.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.blue_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/${var.service_name}/public/*"]
    }
  }

  lifecycle {
    ignore_changes = [action[0].target_group_arn]
  }
}

resource "aws_alb_target_group" "green_target_group" {
  name                 = "tg-${var.environment}-${replace(var.service_name, "_", "-")}-g"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.network.vpc_id
  target_type          = "ip"
  deregistration_delay = 60

  lifecycle {
    create_before_destroy = false
  }

  health_check {
    protocol = "HTTP"
    port     = "80"
    path     = "/healthcheck"
  }

  depends_on = [var.domain, aws_alb_target_group.blue_target_group]

  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}