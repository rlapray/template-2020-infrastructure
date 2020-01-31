output registry {
  value = aws_service_discovery_service.registry
}

output node {
  value = aws_appmesh_virtual_node.node
}

output router {
  value = aws_appmesh_virtual_router.router
}