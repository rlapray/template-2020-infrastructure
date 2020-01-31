output "ecs_execution_role" {
  value = "${aws_iam_role.ecs_execution_role}"
}

output "ecs_service_role_policy" {
  value = "${aws_iam_role_policy.ecs_service_role_policy}"
}

output "autoscale_role" {
  value = "${aws_iam_role.ecs_autoscale_role}"
}