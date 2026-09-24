provider "aws" {
  region = var.aws_region
}

# use default AWS virtual private cloud network
data "aws_vpc" "default" {
  default = true
}

# fetch default subnet info from the default VPC 
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
data "aws_subnet" "primary_subnet" {
  id = data.aws_subnets.default.ids[0]
}

# create isolated subnet for backend cluster traffic (ie. NFS, MPI) 
resource "aws_subnet" "backend_subnet" {
  vpc_id = data.aws_vpc.default.id
  # Choose a CIDR block that does not overlap with your existing default subnets
  cidr_block        = "172.31.250.0/24"
  availability_zone = data.aws_subnet.primary_subnet.availability_zone

  tags = {
    Name = "cluster-backend-subnet"
  }
}

# internal security group for all cluster nodes - management traffic
resource "aws_security_group" "internal_mgmt_sg" {
  name        = "internal-node-mgmt-sg"
  description = "Allow internal cluster mgmt traffic"
  vpc_id      = data.aws_vpc.default.id
}

# internal security group for all cluster nodes - data traffic
resource "aws_security_group" "internal_data_sg" {
  name        = "internal-node-data-sg"
  description = "Allow internal cluster data traffic"
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
    internal_mgmt = aws_security_group.internal_mgmt_sg.id,
    internal_data = aws_security_group.internal_data_sg.id,
    external      = aws_security_group.external_sg.id
  }
  # sum of all cluster nodes regardless of type
  cluster_nodes = var.head_nodes + var.compute_nodes
}

# Allow internal mgmt communication between cluster nodes on eth0
resource "aws_security_group_rule" "allow_cluster_internal_mgmt" {
  for_each = {
    external = aws_security_group.external_sg.id,
    internal = aws_security_group.internal_mgmt_sg.id
  }
  type              = "ingress"
  description       = "Allow all internal mgmt traffic between cluster nodes"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_subnet.primary_subnet.cidr_block]
  security_group_id = each.value
}

# Allow internal data communication between cluster nodes on eth1
resource "aws_security_group_rule" "allow_cluster_internal_data" {
  type              = "ingress"
  description       = "Allow all internal data traffic between cluster nodes"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [aws_subnet.backend_subnet.cidr_block]
  security_group_id = aws_security_group.internal_data_sg.id
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
  key_name = var.AWS_SSH_PUB_KEY

  # provision with durable 100GB disk, will show up as 1st nvme disk
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = false
  }

  # configure eth0 subnet and firewall 
  subnet_id              = data.aws_subnet.primary_subnet.id
  vpc_security_group_ids = [aws_security_group.external_sg.id]

  # allow head node to route compute traffic
  # source_dest_check = false - must do manually in AWS console because 
  # AWS/terraform language issues prevent us from only applying to eth0 
  lifecycle {
    ignore_changes = [source_dest_check]
  }

  tags = {
    Name = "head-node-${count.index}"
  }
}

# assign a static IP to head node eth0 as it has 2 NICs and can't DHCP to eth0
resource "aws_eip" "head_node_eip" {
  domain            = "vpc"
  network_interface = aws_instance.head_nodes[0].primary_network_interface_id
  tags = {
    Name = "head-node-eip-0"
  }
}

# define hardware for compute nodes 
resource "aws_instance" "compute_nodes" {
  count         = var.compute_nodes
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # AWS registered public key for external/internal ssh access
  key_name = var.AWS_SSH_PUB_KEY

  # configure eth0 subnet and firewall 
  subnet_id                   = data.aws_subnet.primary_subnet.id
  vpc_security_group_ids      = [aws_security_group.internal_mgmt_sg.id]
  associate_public_ip_address = false

  tags = {
    Name = "compute-node-${count.index}"
  }
}

# create secondary internal Network Interface for each cluster node
resource "aws_network_interface" "internal_nic" {
  count           = local.cluster_nodes
  subnet_id       = aws_subnet.backend_subnet.id
  security_groups = [aws_security_group.internal_data_sg.id]

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

