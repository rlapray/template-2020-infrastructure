output service_name {
  value = "${aws_ecs_service.web.name}"
}

output target_group_blue {
  value = aws_alb_target_group.blue_target_group
}

output target_group_green {
  value = aws_alb_target_group.green_target_group
}