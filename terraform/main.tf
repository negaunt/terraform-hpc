provider "aws" {
  region = var.aws_region
}

# use default AWS virtual private cloud network
data "aws_vpc" "default" {
  default = true
}

# fetch subnets from the default VPC for the internal NICs
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# internal security group for all cluster nodes
resource "aws_security_group" "internal_sg" {
  name        = "internal-node-sg"
  description = "Allow internal cluster traffic"
  vpc_id      = data.aws_vpc.default.id
}

# external security group for login/admin nodes
resource "aws_security_group" "external_sg" {
  name        = "external-node-sg"
  description = "Allow SSH and internal cluster traffic"
  vpc_id      = data.aws_vpc.default.id
}

# shorthand targets for sg firewall rules 
locals {
  # target for all cluster nodes
  all_cluster_sg_ids = {
    internal = aws_security_group.internal_sg.id,
    external = aws_security_group.external_sg.id
  }
  # sum of all cluster nodes regardless of type
  cluster_nodes = var.head_nodes + var.compute_nodes
}

# Allow internal communication between cluster nodes
resource "aws_security_group_rule" "allow_cluster_internal" {
  for_each          = local.all_cluster_sg_ids
  type              = "ingress"
  description       = "Allow all internal traffic between cluster nodes"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = each.value
}

# Allow outbound communication from cluster nodes
resource "aws_security_group_rule" "allow_cluster_outbound" {
  for_each          = local.all_cluster_sg_ids
  type              = "egress"
  description       = "No filtering on outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = each.value
}

# Allow SSH access only from admin/login nodes
resource "aws_security_group_rule" "allow_external_ssh" {
  type              = "ingress"
  description       = "SSH only from specific IP/subnet for TESTING"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.YOUR_SSH_IP]
  security_group_id = aws_security_group.external_sg.id
}

# set default OS provisioning to Ubuntu 24.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's Verified Owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# define head/admin node config
resource "aws_instance" "head_nodes" {
  count         = var.head_nodes
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # AWS registered public key for external/internal ssh access
  key_name = "terraform-hpc-cluster-ssh-key"

  # provision with durable 100GB disk, will show up as 1st nvme disk
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = false
  }

  # attach to external firewall and internal network
  vpc_security_group_ids = [aws_security_group.external_sg.id]
  subnet_id     = data.aws_subnets.default.ids[0]
  
  tags = {
    Name = "head-node-${count.index}"
  }
}

# define hardware for compute nodes 
resource "aws_instance" "compute_nodes" {
  count         = var.compute_nodes
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # AWS registered public key for external/internal ssh access
  key_name = "terraform-hpc-cluster-ssh-key"

  # attach to internal firewall and network
  vpc_security_group_ids = [aws_security_group.internal_sg.id]
  subnet_id     = data.aws_subnets.default.ids[0]
  associate_public_ip_address = false
  
  tags = {
    Name = "cluster-node-${count.index}"
  }
}

# create secondary internal Network Interface for each cluster node
resource "aws_network_interface" "internal_nic" {
  count           = local.cluster_nodes
  subnet_id       = data.aws_subnets.default.ids[0]
  security_groups = [aws_security_group.internal_sg.id]

  tags = {
    Name = "cluster-internal-nic-${count.index}"
  }
}

# attach the secondary internal NIC (eth1) to head node
resource "aws_network_interface_attachment" "internal_attachment-head" {
  count                = var.head_nodes
  device_index         = 1
  instance_id          = aws_instance.head_nodes[count.index].id
  network_interface_id = aws_network_interface.internal_nic[count.index].id
}

# attach the secondary internal NIC (eth1) to each compute node
resource "aws_network_interface_attachment" "internal_attachment-compute" {
  count                = var.compute_nodes
  device_index         = 1
  instance_id          = aws_instance.compute_nodes[count.index].id
  network_interface_id = aws_network_interface.internal_nic[count.index + var.head_nodes].id
}
