# Automated CI/CD for Java WAR Deployment on Tomcat (AWS EC2)

An enterprise-grade CI/CD pipeline that provisions Jenkins and Tomcat on separate EC2 instances, builds a Java WAR artifact, and automatically deploys it on every push to master.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (VPC)                            │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                      Public Subnet                             │ │
│  │                                                                │ │
│  │   ┌─────────────────────┐       ┌─────────────────────┐       │ │
│  │   │   Jenkins Server    │       │   Tomcat Server     │       │ │
│  │   │   (EC2 Instance)    │  SSH  │   (EC2 Instance)    │       │ │
│  │   │                     │──────▶│                     │       │ │
│  │   │   - Jenkins         │ Deploy│   - Tomcat 9        │       │ │
│  │   │   - Java 11         │  WAR  │   - Java 11         │       │ │
│  │   │   - Maven           │       │   - Application     │       │ │
│  │   │   Port: 8080        │       │   Port: 8080        │       │ │
│  │   └─────────────────────┘       └─────────────────────┘       │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
         │                                        │
         ▼                                        ▼
┌─────────────────┐                    ┌─────────────────┐
│    Developer    │                    │   End Users     │
│  (Push to Git)  │                    │  (Access App)   │
└─────────────────┘                    └─────────────────┘
```

## Technology Stack

| Layer | Tool |
|-------|------|
| Cloud | AWS EC2 |
| IaC | Terraform |
| Configuration | Ansible |
| CI/CD | Jenkins |
| Build | Maven |
| Runtime | Java 11 + Apache Tomcat 9 |
| Source | [simple-java-docker](https://github.com/LondheShubham153/simple-java-docker) |

## Project Structure

```
java-cicd-project/
├── .github/workflows/
│   ├── terraform-apply.yml     # GitHub Actions for Terraform Apply
│   └── terraform-destroy.yml   # GitHub Actions for Terraform Destroy (with approval)
├── terraform/
│   ├── main.tf                 # All infrastructure resources
│   ├── variables.tf            # Input variables with validation
│   ├── outputs.tf              # Output values
│   ├── terraform.tfvars.example
│   └── templates/
│       └── user-data.sh.tpl    # EC2 user data template
├── ansible/
│   ├── ansible.cfg             # Ansible configuration
│   ├── playbook.yml            # Main playbook
│   ├── setup-ssh-keys.yml      # SSH key setup between servers
│   ├── inventory/
│   │   └── hosts.ini           # Dynamic inventory (generated)
│   └── roles/
│       ├── common/             # Base OS configuration
│       ├── java/               # Java 11 installation
│       ├── jenkins/            # Jenkins + Maven setup
│       └── tomcat/             # Tomcat 9 setup
├── jenkins/
│   ├── Jenkinsfile             # Full pipeline with plugins
│   └── Jenkinsfile.simple      # Minimal pipeline
├── scripts/
│   ├── deploy.sh               # Local deployment script
│   └── cleanup.sh              # Local destruction with approval
└── docs/
    └── ARCHITECTURE.md         # Detailed architecture docs
```

## Prerequisites

- AWS Account with appropriate IAM permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- Ansible >= 2.9
- SSH key pair in AWS (note the name)

## Quick Start

### Option A: Deploy with GitHub Actions (Recommended)

#### 1. Setup GitHub Repository Secrets

Go to **Settings > Secrets and variables > Actions** and add:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AWS_KEY_NAME` | EC2 key pair name |

#### 2. Setup GitHub Environment (for Destroy Approval)

Go to **Settings > Environments** and create:

| Environment | Protection Rules |
|-------------|------------------|
| `production` | Required reviewers (add yourself or team) |

This environment gates the destroy workflow - approval is required before destruction.

#### 3. Deploy Infrastructure

- **Automatic**: Push to `main` branch (changes in `terraform/` folder)
- **Manual**: Go to **Actions > Terraform Apply > Run workflow**

No approval needed for apply.

#### 4. Destroy Infrastructure

1. Go to **Actions > Terraform Destroy > Run workflow**
2. Type `DESTROY` in the confirmation field
3. Click **Run workflow**
4. **Approve** when prompted (environment protection)

---

### Option B: Deploy Locally

#### 1. Clone and Configure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region   = "us-east-1"
environment  = "dev"
key_name     = "your-key-pair-name"  # REQUIRED
```

#### 2. Deploy Infrastructure

```bash
# Option A: Use the deployment script
./scripts/deploy.sh

# Option B: Manual steps
cd terraform
terraform init
terraform plan
terraform apply

# Generate Ansible inventory
terraform output -raw ansible_inventory > ../ansible/inventory/hosts.ini
```

### 3. Configure Servers

```bash
cd ansible

# Wait ~60 seconds for EC2 instances to initialize
ansible-playbook -i inventory/hosts.ini playbook.yml

# Setup SSH keys between Jenkins and Tomcat
ansible-playbook -i inventory/hosts.ini setup-ssh-keys.yml
```

### 4. Access Jenkins

```bash
# Get Jenkins URL
cd terraform && terraform output jenkins_url

# Get initial admin password (SSH to Jenkins server)
ssh -i ~/.ssh/your-key.pem ec2-user@<JENKINS_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 5. Configure Jenkins Pipeline

1. Install plugins: Git, Pipeline, SSH Agent
2. Add credentials:
   - `tomcat-host`: Secret text with Tomcat private IP
   - `tomcat-ssh-key`: SSH private key for Tomcat access
3. Create Pipeline job using `jenkins/Jenkinsfile`
4. Configure GitHub webhook: `http://<JENKINS_IP>:8080/github-webhook/`

## Terraform Details

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `environment` | Environment (dev/staging/prod) | `dev` |
| `project_name` | Project name for tags | `java-cicd` |
| `key_name` | SSH key pair name | **Required** |
| `ec2_instances` | Map of EC2 instances | Jenkins + Tomcat |

### Key Features

- **for_each pattern**: Dynamic EC2 and security group creation
- **Input validation**: Region format, environment values
- **Locals**: DRY naming and tagging
- **Encrypted volumes**: EBS encryption enabled
- **Security**: Tomcat 8080 restricted to Jenkins SG

## Ansible Roles

| Role | Purpose |
|------|---------|
| `common` | System updates, packages, NTP |
| `java` | OpenJDK 11 installation |
| `jenkins` | Jenkins, Maven 3.9, SSH keys |
| `tomcat` | Tomcat 9, systemd service, manager config |

## CI/CD Pipeline Stages

1. **Checkout** - Clone from GitHub
2. **Build** - Maven package (WAR)
3. **Test** - Run unit tests
4. **Deploy** - SCP to Tomcat, restart service
5. **Health Check** - Verify application

## Cleanup (IMPORTANT)

To avoid AWS charges, destroy infrastructure when done:

### Option A: GitHub Actions (Recommended)

1. Go to **Actions > Terraform Destroy > Run workflow**
2. Type `DESTROY` in confirmation field
3. Click **Run workflow**
4. **Approve** when prompted

```
┌───────────────────────────────────────────────────────────────┐
│                    DESTROY WORKFLOW                           │
│                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌─────────┐ │
│  │ Validate │───▶│   Plan   │───▶│ APPROVAL │───▶│ Destroy │ │
│  │          │    │          │    │          │    │         │ │
│  │ Type     │    │ tf plan  │    │ Reviewer │    │ tf      │ │
│  │ DESTROY  │    │ -destroy │    │ Required │    │ apply   │ │
│  └──────────┘    └──────────┘    └──────────┘    └─────────┘ │
│                                        │                      │
│                                        ▼                      │
│                               Workflow pauses                 │
│                               until approved                  │
└───────────────────────────────────────────────────────────────┘
```

### Option B: Local Script

```bash
./scripts/cleanup.sh
```

The script requires:
1. Type `DESTROY` to confirm
2. Type `yes` for final confirmation

### Option C: Manual

```bash
cd terraform
terraform destroy
```

## Security Considerations

- SSH access restricted by `allowed_ssh_cidr` (default: 0.0.0.0/0)
- Tomcat Manager remote access enabled (restrict in production)
- Jenkins SSH key auto-generated for Tomcat deployment
- EBS volumes encrypted by default
- No secrets in code (use `terraform.tfvars` or env vars)

## Stretch Goals (Not Implemented)

- [ ] Zero-downtime deployment (rolling restart)
- [ ] Pipeline approval for production
- [ ] Ansible Vault for secrets
- [ ] CloudWatch alarms (CPU/Memory)
- [ ] Tomcat Manager API deployment

## Troubleshooting

### Jenkins can't SSH to Tomcat
```bash
# Run SSH key setup playbook
ansible-playbook -i inventory/hosts.ini setup-ssh-keys.yml
```

### Ansible connection timeout
```bash
# Wait for EC2 instances to fully initialize
sleep 60
ansible all -i inventory/hosts.ini -m ping
```

### Terraform state issues
```bash
terraform refresh
terraform plan
```

## License

MIT
