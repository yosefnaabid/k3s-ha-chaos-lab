output "node_ips" {
  description = "IPs de los nodos del cluster, listas para pegar en el inventario de Ansible"
  value       = { for name, node in var.nodes : name => split("/", node.ip)[0] }
}
