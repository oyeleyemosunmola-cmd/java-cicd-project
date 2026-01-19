#!/bin/bash
set -e

# Set hostname
hostnamectl set-hostname ${hostname}

# Update system
yum update -y

# Install essential packages
yum install -y git wget curl vim unzip

# Tag instance for identification
echo "${server_role}" > /etc/server-role

# Log completion
echo "User data script completed for ${server_role} server" >> /var/log/user-data.log
