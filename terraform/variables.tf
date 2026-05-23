# =============================================================
# variables.tf — Input variable declarations
# Override values via terraform.tfvars or CI/CD environment vars
# =============================================================

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix applied to all resource names"
  type        = string
  default     = "cicd-demo"
}

variable "environment" {
  description = "Deployment environment tag (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into the EC2 instance (restrict to your IP)"
  type        = string
  default     = "0.0.0.0/0" # ← Change to YOUR_IP/32 in production
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID (region-specific)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # us-east-1 Ubuntu 22.04
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the existing AWS key pair for SSH access"
  type        = string
  default     = "my-key-pair"
}

variable "docker_image" {
  description = "Docker Hub image name (username/repo)"
  type        = string
  default     = "yourdockerhubuser/cicd-demo-app"
}

variable "app_version" {
  description = "Docker image tag / application version to deploy"
  type        = string
  default     = "latest"
}
