
/*====
App Load Balancer
======*/
/* security group for ALB */
resource "aws_security_group" "web_inbound_sg" {
  name        = "secgrp-${replace(var.subdomain, ".", "-")}"
  description = "Allow HTTP from Anywhere into ALB"
  vpc_id      = var.network.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "secgrp-${replace(var.subdomain, ".", "-")}"
    Environment = var.environment
  }
}

resource "aws_alb" "alb" {
  name            = "alb-${replace(var.subdomain, ".", "-")}"
  subnets         = var.network.public_subnets_id
  security_groups = concat(var.network.security_groups_ids, [aws_security_group.web_inbound_sg.id])

  tags = {
    Name        = "alb-${replace(var.subdomain, ".", "-")}"
    Environment = var.environment
  }
}

resource "aws_alb_listener" "alb_listener_http" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      status_code = "HTTP_301"
      protocol    = "HTTPS"
      port        = "443"
    }
  }
}

resource "aws_alb_listener" "alb_listener_https" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_route53_record" "name" {
  zone_id = var.route53_zone_id
  name    = var.subdomain
  type    = "A"

  alias {
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
    evaluate_target_health = true
  }
}