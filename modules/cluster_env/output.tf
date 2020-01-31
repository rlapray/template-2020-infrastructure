output "cluster_id" {
  value = "${aws_ecs_cluster.cluster.id}"
}

output "cluster_name" {
  value = "${aws_ecs_cluster.cluster.name}"
}

output "security_group_id" {
  value = "${aws_security_group.ecs_service.id}"
}

output "ecs_service_group" {
  value = "${aws_security_group.ecs_service}"
}

output mesh {
  value = aws_appmesh_mesh.mesh
}

output service_discovery_namespace {
  value = aws_service_discovery_private_dns_namespace.default
}