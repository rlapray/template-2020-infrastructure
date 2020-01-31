output alb {
  value = aws_alb.alb
}

output certificate_arn {
  value = var.certificate_arn
}

output alb_listener_https {
  value = aws_alb_listener.alb_listener_https
}

output alb_listener_http {
  value = aws_alb_listener.alb_listener_http
}