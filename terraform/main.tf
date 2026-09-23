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

resource "aws_instance" "cluster_nodes" {
  count                  = var.cluster_size
  #ami                    = "ami-07c589821f2b3036a" # Ubuntu 24.04 LTS (Verify ID for your region)
  ami = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = "terraform-hpc-cluster-ssh-key"  # created by AWS for EC2 
  vpc_security_group_ids = [aws_security_group.cluster_sg.id]

  tags = {
    Name = "cluster-node-${count.index + 1}"
  }
}

