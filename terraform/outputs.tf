# =============================================================
# outputs.tf — Values printed after `terraform apply`
# =============================================================

output "vpc_id" {
  description = "ID of the provisioned VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "app_url" {
  description = "URL to reach the running application"
  value       = "http://${aws_instance.app_server.public_ip}"
}

output "health_check_url" {
  description = "URL to verify the application health endpoint"
  value       = "http://${aws_instance.app_server.public_ip}/health"
}
