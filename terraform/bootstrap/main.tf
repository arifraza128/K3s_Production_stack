# ==============================================================================
# Phoenix Platform — Terraform Bootstrap Stack (PERSISTENT — NEVER DESTROYED)
# Provisions:
#   - S3 Bucket: tf-state (versioned + encrypted)
#   - S3 Bucket: phoenix-backups (versioned + 30d lifecycle + SSE)
#   - Elastic IP (stable sslip.io hostname across DR drills)
#   - AWS Budget + Email Alert
#   - IAM Role + Instance Profile (SSM Session Manager + backup bucket prefix R/W)
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
      stack   = "bootstrap"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "budget_email" {
  type    = string
  default = "arif3raza@gmail.com"
}

variable "budget_limit_usd" {
  type    = string
  default = "10.0"
}

variable "backup_bucket_name" {
  type    = string
  default = "phoenix-backups-ap-south-1-arifraza128"
}

resource "aws_s3_bucket" "phoenix_backups" {
  bucket = var.backup_bucket_name
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "phoenix_backups" {
  bucket = aws_s3_bucket.phoenix_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "phoenix_backups" {
  bucket = aws_s3_bucket.phoenix_backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "phoenix_backups" {
  bucket                  = aws_s3_bucket.phoenix_backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "phoenix_backups" {
  bucket = aws_s3_bucket.phoenix_backups.id
  rule {
    id     = "expire-old-backups-30d"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_eip" "phoenix_eip" {
  domain = "vpc"
  tags = {
    Name = "phoenix-stable-eip"
  }
}

resource "aws_budgets_budget" "phoenix_monthly" {
  name              = "phoenix-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.budget_limit_usd
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-11-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}

resource "aws_iam_role" "phoenix_node_role" {
  name = "phoenix-k3s-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "phoenix_backup_rw" {
  name = "phoenix-backup-bucket-rw"
  role = aws_iam_role.phoenix_node_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.phoenix_backups.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.phoenix_backups.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.phoenix_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "phoenix_node_profile" {
  name = "phoenix-k3s-node-profile"
  role = aws_iam_role.phoenix_node_role.name
}

output "eip_allocation_id" {
  value = aws_eip.phoenix_eip.id
}

output "public_ip" {
  value = aws_eip.phoenix_eip.public_ip
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.phoenix_node_profile.name
}

output "backup_bucket_name" {
  value = aws_s3_bucket.phoenix_backups.bucket
}
