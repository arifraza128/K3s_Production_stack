# ==============================================================================
# Phoenix Platform — Terraform Platform Stack (DESTROYABLE IN DR DRILLS)
# Provisions:
#   - Security Group (80/443 public only; access via SSM Session Manager)
#   - EC2 ARM64 Instance (Ubuntu 22.04 LTS via SSM, 30GB gp3, instance profile)
#   - Elastic IP Association (links persistent bootstrap EIP to new instance)
# ==============================================================================

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
  default_tags {
    tags = {
      project = "phoenix"
      stack   = "platform"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 ARM64 instance type (PRD A1: t4g.medium 4GB recommended for full stack)"
  type        = string
  default     = "t4g.medium"
}

variable "eip_allocation_id" {
  description = "Allocation ID of the persistent Elastic IP from terraform/bootstrap"
  type        = string
  default     = ""
}

variable "instance_profile_name" {
  description = "IAM Instance Profile from terraform/bootstrap (SSM + S3 backup access)"
  type        = string
  default     = "phoenix-k3s-node-profile"
}

data "aws_ssm_parameter" "ubuntu_arm64" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id"
}

resource "aws_security_group" "phoenix_platform_sg" {
  name        = "phoenix-platform-sg"
  description = "Security group allowing HTTP 80 and HTTPS 443 only (SSM used for shell/API access)"

  ingress {
    description = "HTTP (ACME HTTP-01 + redirect)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (ingress-nginx TLS)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound traffic (SSM, GHCR, S3, Let's Encrypt)"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "phoenix_k3s" {
  ami                  = data.aws_ssm_parameter.ubuntu_arm64.value
  instance_type        = var.instance_type
  iam_instance_profile = var.instance_profile_name

  vpc_security_group_ids = [aws_security_group.phoenix_platform_sg.id]
  user_data              = file("${path.module}/../../cloud-init/k3s-install.yaml")

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "phoenix-k3s-node"
  }
}

resource "aws_eip_association" "phoenix_eip_assoc" {
  count         = var.eip_allocation_id != "" ? 1 : 0
  instance_id   = aws_instance.phoenix_k3s.id
  allocation_id = var.eip_allocation_id
}

output "instance_id" {
  value = aws_instance.phoenix_k3s.id
}
