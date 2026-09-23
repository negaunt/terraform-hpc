output "head_node_public_ips" {
  value = aws_instance.head_nodes[*].public_ip
}
output "head_node_private_ips" {
  value = [
    for i in range(0, var.head_nodes) : 
    aws_network_interface.internal_nic[i].private_ip
  ]
}
output "compute_node_public_ips" {
  value = aws_instance.compute_nodes[*].public_ip
}
output "compute_node_private_ips" {
  value = [
    for i in range(var.head_nodes, var.head_nodes + var.compute_nodes) : 
    aws_network_interface.internal_nic[i].private_ip
  ]
}
output "AWS_SSH_PRIV_KEY" {
  value = var.AWS_SSH_PRIV_KEY
}
