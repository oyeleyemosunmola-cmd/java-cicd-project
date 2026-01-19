#!/bin/bash
#####################################
# Full Deployment Script
# Provisions infrastructure and configures servers
#####################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Java CI/CD Infrastructure Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "\n${YELLOW}Checking prerequisites...${NC}"

    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Terraform is not installed. Please install Terraform >= 1.0${NC}"
        exit 1
    fi

    if ! command -v ansible &> /dev/null; then
        echo -e "${RED}Ansible is not installed. Please install Ansible >= 2.9${NC}"
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Please install and configure AWS CLI${NC}"
        exit 1
    fi

    echo -e "${GREEN}All prerequisites met!${NC}"
}

# Deploy infrastructure
deploy_infrastructure() {
    echo -e "\n${YELLOW}Step 1: Deploying Infrastructure with Terraform...${NC}"

    cd "$PROJECT_DIR/terraform"

    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "${RED}terraform.tfvars not found!${NC}"
        echo -e "Please copy terraform.tfvars.example to terraform.tfvars and update values"
        exit 1
    fi

    terraform init
    terraform validate

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}         TERRAFORM PLAN OUTPUT          ${NC}"
    echo -e "${BLUE}========================================${NC}\n"

    terraform plan -out=tfplan

    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}         APPROVAL REQUIRED              ${NC}"
    echo -e "${YELLOW}========================================${NC}"

    echo -e "\n${YELLOW}The above plan will create AWS resources that incur costs.${NC}"
    echo -e "\nResources to be created:"
    echo "  - VPC with public subnet"
    echo "  - 2 EC2 instances (Jenkins + Tomcat)"
    echo "  - 2 Elastic IPs"
    echo "  - Security groups"

    echo -e "\n${YELLOW}Type 'APPLY' (all caps) to approve and create resources:${NC}"
    read -r confirmation

    if [ "$confirmation" != "APPLY" ]; then
        echo -e "\n${GREEN}Deployment cancelled. No resources created.${NC}"
        rm -f tfplan
        exit 0
    fi

    echo -e "\n${YELLOW}Final confirmation - This will create billable AWS resources. Continue? (yes/no)${NC}"
    read -r final_confirmation

    if [ "$final_confirmation" != "yes" ]; then
        echo -e "\n${GREEN}Deployment cancelled. No resources created.${NC}"
        rm -f tfplan
        exit 0
    fi

    # Execute apply
    echo -e "\n${GREEN}Applying Terraform plan...${NC}"
    terraform apply tfplan
    rm -f tfplan

    # Generate Ansible inventory
    echo -e "\n${YELLOW}Generating Ansible inventory...${NC}"
    terraform output -raw ansible_inventory > "$PROJECT_DIR/ansible/inventory/hosts.ini"
    echo -e "${GREEN}Ansible inventory generated!${NC}"
}

# Configure servers
configure_servers() {
    echo -e "\n${YELLOW}Step 2: Configuring Servers with Ansible...${NC}"

    cd "$PROJECT_DIR/ansible"

    # Wait for instances to be ready
    echo -e "${YELLOW}Waiting 60 seconds for EC2 instances to be ready...${NC}"
    sleep 60

    # Run Ansible playbook
    ansible-playbook -i inventory/hosts.ini playbook.yml

    echo -e "${GREEN}Server configuration complete!${NC}"
}

# Setup SSH keys
setup_ssh_keys() {
    echo -e "\n${YELLOW}Step 3: Setting up SSH keys between Jenkins and Tomcat...${NC}"

    cd "$PROJECT_DIR/ansible"
    ansible-playbook -i inventory/hosts.ini setup-ssh-keys.yml

    echo -e "${GREEN}SSH key setup complete!${NC}"
}

# Print access information
print_access_info() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"

    cd "$PROJECT_DIR/terraform"

    echo -e "\n${YELLOW}Access URLs:${NC}"
    echo -e "Jenkins: $(terraform output -raw jenkins_url)"
    echo -e "Tomcat:  $(terraform output -raw tomcat_url)"

    echo -e "\n${YELLOW}SSH Commands:${NC}"
    terraform output -json ssh_commands | jq -r 'to_entries[] | "\(.key): \(.value)"'

    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Access Jenkins UI and complete initial setup"
    echo "2. Install required Jenkins plugins (Git, Pipeline, SSH Agent)"
    echo "3. Configure Jenkins credentials for Tomcat SSH access"
    echo "4. Create a new Pipeline job using the Jenkinsfile"
    echo "5. Configure GitHub webhook for automatic deployments"

    echo -e "\n${RED}IMPORTANT: Run ./scripts/cleanup.sh when done to avoid AWS charges${NC}"
}

# Main execution
main() {
    check_prerequisites
    deploy_infrastructure
    configure_servers
    setup_ssh_keys
    print_access_info
}

main "$@"
