####################################
# TERRAFORM CONFIGURATION
####################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state (recommended for teams)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "java-cicd/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

####################################
# PROVIDER
####################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

####################################
# DATA SOURCES
####################################

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

####################################
# LOCAL VALUES
####################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  ami_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2.id
  az          = data.aws_availability_zones.available.names[0]

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.common_tags
  )
}

####################################
# VPC
####################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

####################################
# INTERNET GATEWAY
####################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

####################################
# PUBLIC SUBNET
####################################

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet"
    Type = "public"
  }
}

####################################
# ROUTE TABLE
####################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

####################################
# SECURITY GROUPS
####################################

resource "aws_security_group" "servers" {
  for_each = var.ec2_instances

  name        = "${local.name_prefix}-${each.key}-sg"
  description = "Security group for ${each.key} server"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-${each.key}-sg"
    Role = each.value.role
  }

  lifecycle {
    create_before_destroy = true
  }
}

####################################
# SECURITY GROUP RULES - SSH
####################################

resource "aws_security_group_rule" "ssh" {
  for_each = var.ec2_instances

  type              = "ingress"
  description       = "SSH access"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ssh_cidr]
  security_group_id = aws_security_group.servers[each.key].id
}

####################################
# SECURITY GROUP RULES - APPLICATION PORTS
####################################

resource "aws_security_group_rule" "app_ports" {
  for_each = var.ec2_instances

  type              = "ingress"
  description       = "${each.key} application port"
  from_port         = each.value.ports[0]
  to_port           = each.value.ports[0]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.servers[each.key].id
}

####################################
# SECURITY GROUP RULE - TOMCAT FROM JENKINS
####################################

resource "aws_security_group_rule" "tomcat_from_jenkins" {
  type                     = "ingress"
  description              = "Tomcat access from Jenkins SG"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.servers["jenkins"].id
  security_group_id        = aws_security_group.servers["tomcat"].id
}

####################################
# EC2 INSTANCES
####################################

resource "aws_instance" "servers" {
  for_each = var.ec2_instances

  ami                    = local.ami_id
  instance_type          = each.value.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.servers[each.key].id]

  root_block_device {
    volume_size           = each.value.volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.name_prefix}-${each.key}-root"
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh.tpl", {
    server_role = each.value.role
    hostname    = "${local.name_prefix}-${each.key}"
  }))

  tags = {
    Name = "${local.name_prefix}-${each.key}"
    Role = each.value.role
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

####################################
# ELASTIC IPs
####################################

resource "aws_eip" "servers" {
  for_each = var.ec2_instances

  instance = aws_instance.servers[each.key].id
  domain   = "vpc"

  tags = {
    Name = "${local.name_prefix}-${each.key}-eip"
    Role = each.value.role
  }

  depends_on = [aws_internet_gateway.main]
}
# Trigger workflow
