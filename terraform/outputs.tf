output "instance_ips" {
  value = aws_instance.cluster_nodes[*].public_ip
}
