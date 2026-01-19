# CI/CD Architecture for Java WAR Deployment on Tomcat (AWS EC2)

## Overview

This project implements automated CI/CD for a Java web application deployed as a WAR file on Apache Tomcat running on AWS EC2 instances.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (VPC)                                │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        Public Subnet                                 │   │
│  │                                                                      │   │
│  │   ┌─────────────────────┐         ┌─────────────────────┐          │   │
│  │   │   Jenkins Server    │         │   Tomcat Server     │          │   │
│  │   │   (EC2 Instance)    │         │   (EC2 Instance)    │          │   │
│  │   │                     │  SSH    │                     │          │   │
│  │   │   - Jenkins         │────────▶│   - Tomcat 9        │          │   │
│  │   │   - Java 11         │  Deploy │   - Java 11         │          │   │
│  │   │   - Maven           │   WAR   │   - Application     │          │   │
│  │   │   - Git             │         │                     │          │   │
│  │   │                     │         │                     │          │   │
│  │   │   Port: 8080        │         │   Port: 8080        │          │   │
│  │   └─────────────────────┘         └─────────────────────┘          │   │
│  │            │                               │                        │   │
│  └────────────│───────────────────────────────│────────────────────────┘   │
│               │                               │                             │
│  ┌────────────▼───────────────────────────────▼────────────────────────┐   │
│  │                      Security Groups                                 │   │
│  │   - Jenkins SG: Allow 8080, 22 from anywhere                        │   │
│  │   - Tomcat SG: Allow 8080 from Jenkins SG only, 22 from anywhere    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
         │                                             │
         │                                             │
         ▼                                             ▼
┌─────────────────┐                          ┌─────────────────┐
│    Developer    │                          │   End Users     │
│   Push to Git   │                          │  Access App     │
└─────────────────┘                          └─────────────────┘
```

## Components

### 1. Infrastructure Layer (Terraform)

| Component | Description |
|-----------|-------------|
| VPC | Virtual Private Cloud with CIDR 10.0.0.0/16 |
| Public Subnet | Subnet for EC2 instances with internet access |
| Internet Gateway | Enables internet connectivity |
| Route Table | Routes traffic to internet gateway |
| Security Groups | Controls inbound/outbound traffic |
| EC2 Instances | Jenkins server and Tomcat server |

### 2. Configuration Layer (Ansible)

| Role | Purpose |
|------|---------|
| common | Base OS configuration, updates, essential packages |
| java | Install OpenJDK 11 |
| jenkins | Install and configure Jenkins CI server |
| tomcat | Install and configure Apache Tomcat 9 |

### 3. CI/CD Pipeline (Jenkins)

**Pipeline Stages:**

1. **Checkout** - Clone repository from GitHub
2. **Build** - Compile Java code and package as WAR using Maven
3. **Test** - Run unit tests (if available)
4. **Deploy** - Transfer WAR to Tomcat server via SSH
5. **Restart** - Restart Tomcat service to load new deployment

## Security Measures

1. **SSH-based deployment** - Jenkins uses SSH keys to deploy to Tomcat
2. **Restricted Security Groups** - Tomcat port 8080 only accessible from Jenkins
3. **Credentials Management** - SSH keys stored in Jenkins credentials store
4. **No public application access** - Tomcat admin interface not exposed

## Workflow

```
Developer pushes code to GitHub (master branch)
                    │
                    ▼
        GitHub Webhook triggers Jenkins
                    │
                    ▼
        Jenkins pulls latest code
                    │
                    ▼
        Maven builds WAR artifact
                    │
                    ▼
        Jenkins copies WAR to Tomcat via SCP
                    │
                    ▼
        Jenkins restarts Tomcat service via SSH
                    │
                    ▼
        Application deployed and accessible
```

## File Structure

```
java-cicd-project/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── security-groups.tf
│   ├── ec2-jenkins.tf
│   └── ec2-tomcat.tf
├── ansible/
│   ├── inventory/
│   │   └── hosts.ini
│   ├── roles/
│   │   ├── common/
│   │   ├── java/
│   │   ├── jenkins/
│   │   └── tomcat/
│   ├── playbook.yml
│   └── ansible.cfg
├── jenkins/
│   └── Jenkinsfile
├── app/
│   ├── pom.xml
│   └── src/
├── scripts/
│   ├── deploy.sh
│   └── cleanup.sh
└── docs/
    └── ARCHITECTURE.md
```

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- Ansible >= 2.9
- SSH key pair for EC2 access
- GitHub account (for webhook configuration)
