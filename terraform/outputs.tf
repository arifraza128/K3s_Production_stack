output "public_ip" {
  description = "The Elastic IP address assigned to the K3s server"
  value       = aws_eip.k3s_eip.public_ip
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.k3s_server.id
}

output "ssh_command" {
  description = "Command to SSH into the K3s instance"
  value       = var.key_name != "" ? "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.k3s_eip.public_ip}" : "ssh ubuntu@${aws_eip.k3s_eip.public_ip}"
}

