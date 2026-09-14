variable "aws_region" {
  default = "us-west-2"
}

variable "instance_type" {
  description = "AWS EC2 instance type (e.g., t3.small, t3.medium, m6i.large)"
  default = "t3.small" # 2 vcpu, 2GB ram 
}

variable "cluster_size" {
  default = 1 
}

variable "existing_s3_bucket" {
  type = string
  description = "negaunt-git-tutorials-292600391949-us-west-2-an"
}
