provider "aws" {
  region = var.aws_region
}

# use default AWS virtual private cloud network
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "cluster_sg" {
  name        = "cluster-node-sg"
  description = "Allow SSH and internal cluster traffic"
  vpc_id      = data.aws_vpc.default.id

  # allow inbound SSH access from home cable modem WAN IP
  ingress {
    description = "SSH from anywhere (restrict to your IP in production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.YOUR_SSH_IP]
  }

  # cluster node <-> node communication
  ingress {
    description = "Allow all internal traffic between cluster nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # no filtering on cluster node outbound firewalls
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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

output "instance_ips" {
  value = aws_instance.cluster_nodes[*].public_ip
}
