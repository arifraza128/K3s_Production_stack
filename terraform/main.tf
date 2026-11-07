terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Lookup Ubuntu 22.04 LTS ARM64 AMI via AWS SSM Parameter Store
data "aws_ssm_parameter" "ubuntu_arm64" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id"
}

# Security Group for K3s Single-Node Cluster
resource "aws_security_group" "k3s_sg" {
  name        = "k3s-production-sg"
  description = "Security group for K3s production server"

  # SSH access (restricted by my_ip)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # K3s Kubernetes API server (restricted by my_ip)
  ingress {
    description = "K3s Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # HTTP Ingress
  ingress {
    description = "HTTP Web Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS Ingress
  ingress {
    description = "HTTPS Secure Web Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort Services (30000-32767)
  ingress {
    description = "Kubernetes NodePort Range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Internet Access
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "k3s-production-sg"
  }
}

# EC2 Instance for K3s Node
resource "aws_instance" "k3s_server" {
  ami           = data.aws_ssm_parameter.ubuntu_arm64.value
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  # User data cloud-init script
  user_data = file("${path.module}/../cloud-init/k3s-install.yaml")

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "k3s-production-server"
  }
}

# Elastic IP attached to the K3s server
resource "aws_eip" "k3s_eip" {
  instance = aws_instance.k3s_server.id
  domain   = "vpc"

  tags = {
    Name = "k3s-eip"
  }
}

