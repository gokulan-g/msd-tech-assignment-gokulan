# Infrastructure Automation Assignment

## 📘 Overview

This project automates the provisioning and configuration of a web infrastructure stack using **Terraform**, **Ansible**, and **GitHub Actions** on **AWS**. It deploys a high-availability setup with a PostgreSQL database and dynamic content rendered from the database on NGINX web servers.

---

## 🏗️ Infrastructure Provisioning (Terraform)

* **EC2 Instances**

  * 2 x Ubuntu EC2 instances
  * Distributed across `ap-south-1a` and `ap-south-1b`
  * Connected via an Application Load Balancer (ALB)

* **PostgreSQL RDS**

  * Free Tier instance
  * Security group `connect-to-rds` allows port `5432` in/out
  * Publicly accessible for demo purposes

* **ALB (Application Load Balancer)**

  * Targets both EC2 instances
  * Sticky sessions disabled (`lb_cookie`)

* **Route 53 DNS**

  * `A` record pointing to ALB (`gokulang.com`)

---

## ⚙️ Configuration Management (Ansible)

### 🖥️ Localhost Tasks

* Parse `terraform.tfstate` to generate dynamic inventory
* Extract RDS endpoint
* Create and populate PostgreSQL table `cars`

### 🌐 Webserver Tasks

* Install and configure NGINX
* Render dynamic `index.html` containing:

  * Hostname of EC2
  * Data from PostgreSQL (`cars` table)
* NGINX watchdog cron job to ensure service uptime

---

## 🔄 Continuous Deployment (GitHub Actions)

* Secure role-based access to AWS using OIDC (`msd-tech-assignment-aws-role`)
* `workflow_dispatch` to trigger `apply` or `destroy`
* Terraform plan/apply integrated with GitHub Secrets
* Inventory file is regenerated after provisioning

---

## 🔐 Security & Best Practices

* SSH key permissions validated
* DB passwords injected using GitHub Secrets
* No hardcoded secrets in Ansible or Terraform
* Python interpreter explicitly set for compatibility

---

## 🌐 Dynamic Web Content Sample

Example content of `index.html` rendered by each server:

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

## 🧪 Validations Performed

* Verified SSH access to EC2 instances
* Verified load balancing across two AZs
* Verified PostgreSQL data read and insert
* Confirmed HTML rendering and NGINX service watchdog

---

## 📅 Release Info

* **Version:** 1.0.0
* **Author:** Gokulan Guberan
* **Date:** July 20, 2025

---
