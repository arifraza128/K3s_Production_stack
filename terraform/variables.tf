variable "region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type for the K3s node (ARM64 architecture)"
  type        = string
  default     = "t4g.small"
}

variable "key_name" {
  description = "The name of the AWS EC2 Key Pair to use for SSH access"
  type        = string
  default     = "my-k3s-key"
}

variable "my_ip" {
  description = "CIDR block allowed to access administrative ports (SSH and K3s API). Example: '203.0.113.4/32'"
  type        = string
  default     = "0.0.0.0/0"
}

