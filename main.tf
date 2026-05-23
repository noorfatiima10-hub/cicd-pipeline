# =============================================================
# main.tf — Core infrastructure for the CI/CD demo app
# Provider: AWS  |  Resources: VPC, Subnet, SG, EC2
# =============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------
# VPC — isolated virtual network
# ------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------
# Internet Gateway — allows VPC traffic to reach the internet
# ------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ------------------------------------------------------------------
# Public Subnet
# ------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# ------------------------------------------------------------------
# Route Table — route all outbound traffic via the IGW
# ------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------
# Security Group — ONLY ports 80, 443, and 22 (SSH) are open
# All outbound traffic is permitted.
# ------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Allow HTTP, HTTPS, and SSH inbound; all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH (restrict to your IP in production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ------------------------------------------------------------------
# EC2 Instance — Docker host that runs the containerized app
# User-data script installs Docker and pulls the latest image.
# ------------------------------------------------------------------
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_pair_name

  # Bootstrap script: installs Docker and starts the application container
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker

    # Pull and run the app container with a health-check-aware restart policy
    docker pull ${var.docker_image}:${var.app_version}

    docker run -d \
      --name app \
      --restart unless-stopped \
      -p 80:5000 \
      -e APP_VERSION=${var.app_version} \
      --health-cmd="curl -f http://localhost:5000/health || exit 1" \
      --health-interval=15s \
      --health-timeout=5s \
      --health-retries=3 \
      ${var.docker_image}:${var.app_version}
  EOF

  tags = {
    Name        = "${var.project_name}-server"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
