# Webserver as Code

## Continuous Deployment (GitHub Actions)

This project uses GitHub Actions to automate provisioning and configuration. The pipeline is triggered manually using `workflow_dispatch` and supports `apply` or `destroy` actions via input.

### Workflow Summary

- **Secure AWS access** using OIDC role `msd-tech-assignment-aws-role`
- `workflow_dispatch` trigger with input selection (`apply` or `destroy`)
- **Secrets** like `DB_PASSWORD` and `SSH_PRIVATE_KEY` managed via GitHub Secrets
- Two-phase execution:
  - **Infra-As-Code**: Runs Terraform
  - **Config-As-Code**: Runs Ansible (only during `apply`)

### Terraform Phase

- Initializes Terraform and applies or destroys resources
- State is committed back to the repository
- Generates output for EC2 IPs and RDS endpoints

### Ansible Phase (applies only when action is `apply`)

- Installs Ansible and required collections
- Saves SSH private key from GitHub Secrets
- Parses Terraform state to generate `inventories.ini`
- Executes playbooks to:
  - Install NGINX
  - Create and populate PostgreSQL table
  - Render dynamic content

### Example Trigger Block

```yaml
on:
  workflow_dispatch:
    inputs:
      terraform_action:
        description: 'Select Terraform Action'
        required: true
        default: 'apply'
        type: choice
        options:
          - apply
          - destroy
```

### Notes

- Ansible is skipped when `terraform_action == destroy`
- Sensitive credentials are masked in logs
- SSH key is handled in-memory and not written to disk outside GitHub runner

---

## Overview

This project automates the provisioning and configuration of a web infrastructure stack using Terraform, Ansible, and GitHub Actions on AWS. It deploys a high-availability setup with a PostgreSQL database and dynamically generates Ansible inventory and content rendered on NGINX web servers.

---

## Infrastructure Provisioning (Terraform)

- **EC2 Instances**
  - 2 x Ubuntu EC2 instances
  - Distributed across `ap-south-1a` and `ap-south-1b`
  - Connected via an Application Load Balancer (ALB)

- **PostgreSQL RDS**
  - Free Tier instance
  - Security group `connect-to-rds` allows port `5432` in/out
  - Publicly accessible for demo purposes

- **ALB (Application Load Balancer)**
  - Targets both EC2 instances
  - Sticky sessions disabled (`lb_cookie`)

- **Route 53 DNS**
  - `A` record pointing to ALB (`gokulang.com`)

---

## Configuration Management (Ansible)

### Localhost Tasks

- Download `terraform.tfstate` from S3
- Parse `terraform.tfstate` to generate dynamic inventory (`inventories.ini`)
- Extract RDS connection details (hostname, port, user, password)
- Create PostgreSQL table `cars` using `community.postgresql.postgresql_query`
- Insert seed records into the `cars` table

### Webserver Tasks

- Install and configure NGINX
- Render dynamic `index.html` using EC2 hostname and DB table `cars` data
- Add a cron-based watchdog to auto-restart NGINX if stopped

---

## Security and Best Practices

- SSH key permissions are enforced
- DB passwords and secrets are never hardcoded and used in hit
- All sensitive variables are marked with `no_log: true` in Ansible
- Python interpreter explicitly declared for controlled environments

---

## Dynamic Web Content Sample

Example of `index.html` rendered on each server:

```html
<table>
  <tr><td>Hello World!</td></tr>
  <tr><td>ip-10-0-1-123</td></tr>
</table>
<table>
  <tr><th>ID</th><th>Brand</th><th>Model</th><th>Year</th></tr>
  <tr><td>1</td><td>Toyota</td><td>Corolla</td><td>2020</td></tr>
  <tr><td>2</td><td>Honda</td><td>Civic</td><td>2019</td></tr>
  <tr><td>3</td><td>Ford</td><td>Mustang</td><td>2021</td></tr>
</table>
```

---

## Validations Performed

- Verified SSH access to EC2 instances
- Verified load balancing across two AZs
- Verified PostgreSQL connectivity and data manipulation via Ansible
- Validated dynamic inventory generation from Terraform state
- Confirmed `cars` table was created and populated correctly

---

## Release Info

- Version: 1.0.0
- Author: Gokulan Guberan
- Date: July 23, 2025
