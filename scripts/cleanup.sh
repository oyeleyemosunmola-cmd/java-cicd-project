#!/bin/bash
#####################################
# Cleanup Script with Approval Step
# Destroys all AWS infrastructure
#####################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${RED}========================================${NC}"
echo -e "${RED}     INFRASTRUCTURE DESTRUCTION        ${NC}"
echo -e "${RED}========================================${NC}"

echo -e "\n${YELLOW}WARNING: This will destroy ALL infrastructure:${NC}"
echo "  - Jenkins EC2 instance"
echo "  - Tomcat EC2 instance"
echo "  - Elastic IPs"
echo "  - Security Groups"
echo "  - VPC and all networking"

cd "$PROJECT_DIR/terraform"

# Show what will be destroyed
echo -e "\n${YELLOW}Planning destruction...${NC}"
terraform plan -destroy -out=destroy.tfplan

echo -e "\n${RED}========================================${NC}"
echo -e "${RED}         APPROVAL REQUIRED              ${NC}"
echo -e "${RED}========================================${NC}"

echo -e "\n${YELLOW}Type 'DESTROY' (all caps) to confirm destruction:${NC}"
read -r confirmation

if [ "$confirmation" != "DESTROY" ]; then
    echo -e "\n${GREEN}Destruction cancelled. Infrastructure preserved.${NC}"
    rm -f destroy.tfplan
    exit 0
fi

echo -e "\n${YELLOW}Final confirmation: Are you absolutely sure? (yes/no)${NC}"
read -r final_confirmation

if [ "$final_confirmation" != "yes" ]; then
    echo -e "\n${GREEN}Destruction cancelled. Infrastructure preserved.${NC}"
    rm -f destroy.tfplan
    exit 0
fi

# Execute destruction
echo -e "\n${RED}Destroying infrastructure...${NC}"
terraform apply destroy.tfplan

# Cleanup local files
rm -f destroy.tfplan
rm -f "$PROJECT_DIR/ansible/inventory/hosts.ini"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Infrastructure destroyed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Cleanup complete. No AWS charges will be incurred.${NC}"
