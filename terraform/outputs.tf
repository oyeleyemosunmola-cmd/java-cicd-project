####################################
# VPC Outputs
####################################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public.id
}

####################################
# EC2 Instance Outputs
####################################

output "instance_ids" {
  description = "Map of instance IDs"
  value       = { for k, v in aws_instance.servers : k => v.id }
}

output "public_ips" {
  description = "Map of public IPs (Elastic IPs)"
  value       = { for k, v in aws_eip.servers : k => v.public_ip }
}

output "private_ips" {
  description = "Map of private IPs"
  value       = { for k, v in aws_instance.servers : k => v.private_ip }
}

####################################
# Convenience Outputs
####################################

output "jenkins_url" {
  description = "Jenkins Web UI URL"
  value       = "http://${aws_eip.servers["jenkins"].public_ip}:8080"
}

output "tomcat_url" {
  description = "Tomcat Web UI URL"
  value       = "http://${aws_eip.servers["tomcat"].public_ip}:8080"
}

output "jenkins_public_ip" {
  description = "Jenkins Public IP"
  value       = aws_eip.servers["jenkins"].public_ip
}

output "tomcat_public_ip" {
  description = "Tomcat Public IP"
  value       = aws_eip.servers["tomcat"].public_ip
}

output "tomcat_private_ip" {
  description = "Tomcat Private IP (for Jenkins SSH)"
  value       = aws_instance.servers["tomcat"].private_ip
}

####################################
# Security Group Outputs
####################################

output "security_group_ids" {
  description = "Map of security group IDs"
  value       = { for k, v in aws_security_group.servers : k => v.id }
}

####################################
# Ansible Inventory Output
####################################

output "ansible_inventory" {
  description = "Ansible inventory content - copy to ansible/inventory/hosts.ini"
  value       = <<-EOT
    [jenkins]
    ${aws_eip.servers["jenkins"].public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem

    [tomcat]
    ${aws_eip.servers["tomcat"].public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem

    [all:vars]
    ansible_python_interpreter=/usr/bin/python3
    tomcat_private_ip=${aws_instance.servers["tomcat"].private_ip}
    jenkins_private_ip=${aws_instance.servers["jenkins"].private_ip}
  EOT
}

####################################
# SSH Connection Commands
####################################

output "ssh_commands" {
  description = "SSH commands to connect to servers"
  value = {
    jenkins = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.servers["jenkins"].public_ip}"
    tomcat  = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.servers["tomcat"].public_ip}"
  }
}
