####################################
# General Configuration
####################################

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1)."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
  default     = "java-cicd"
}

####################################
# Network Configuration
####################################

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access (restrict in production)"
  type        = string
  default     = "0.0.0.0/0"
}

####################################
# EC2 Configuration
####################################

variable "key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty for latest Amazon Linux 2)"
  type        = string
  default     = ""
}

variable "ec2_instances" {
  description = "Map of EC2 instances to create"
  type = map(object({
    instance_type = string
    volume_size   = number
    role          = string
    ports         = list(number)
  }))

  default = {
    jenkins = {
      instance_type = "t2.medium"
      volume_size   = 30
      role          = "jenkins"
      ports         = [8080]
    }
    tomcat = {
      instance_type = "t2.medium"
      volume_size   = 20
      role          = "tomcat"
      ports         = [8080]
    }
  }
}

####################################
# Tags
####################################

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
