# Security group to allow incoming/outgoing PostgreSQL traffic (port 5432)
resource "aws_security_group" "connect_to_rds" {
  name        = "connect-to-rds"
  description = "Allow access on port 5432"

  ingress {
    description = "Allow PostgreSQL from anywhere"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open to the world — restrict in production
  }

  egress {
    description = "Allow PostgreSQL from anywhere"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open egress — usually fine, but tighten if needed
  }

  tags = {
    Name = "connect-to-rds"
  }
}

# Fetches the latest PostgreSQL engine version from AWS
data "aws_rds_engine_version" "postgres_latest" {
  engine = "postgres"
}

# RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  identifier                   = "msd-assignment-db"
  engine                       = "postgres"
  engine_version               = data.aws_rds_engine_version.postgres_latest.version  # Automatically fetch latest version
  instance_class               = "db.t4g.micro"
  allocated_storage            = 20
  storage_type                 = "gp2"
  storage_encrypted            = false
  db_name                      = "mydb"
  username                     = "postgres"
  password                     = var.db_password  # Best to store this in AWS Secrets Manager or use TF Cloud variable
  publicly_accessible          = true             # RDS is open to the internet — secure with IP restrictions
  multi_az                     = false
  vpc_security_group_ids       = [aws_security_group.connect_to_rds.id]
  skip_final_snapshot          = true
  deletion_protection          = false
  backup_retention_period      = 0
  auto_minor_version_upgrade   = false
  performance_insights_enabled = false
  copy_tags_to_snapshot        = false
}

#############################################
# Data Sources for Ubuntu AMI and VPC Info
#############################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical — official Ubuntu images

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch subnets that are default in specific AZs
data "aws_subnets" "filtered_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }

  filter {
    name   = "availability-zone"
    values = ["ap-south-1a", "ap-south-1b"]  # Limits subnets to 2 AZs
  }
}

##########################################
# SG to allow SSH, HTTP, HTTPS traffic
##########################################
resource "aws_security_group" "ssh_access" {
  name        = "allow_ssh"
  description = "Allow SSH and HTTP/HTTPS inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open to all IPs — restrict in production
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################
# EC2 Ubuntu web servers (count = variable)
###############################################
resource "aws_instance" "ubuntu_server" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_instance_private_key

  subnet_id              = element(data.aws_subnets.filtered_subnets.ids, count.index)
  vpc_security_group_ids = [aws_security_group.ssh_access.id]

  tags = {
    Name = "${var.server_name}${count.index + 1}"
  }
}

#########################################
# Application Load Balancer (ALB)
#########################################
resource "aws_lb" "assignment_lb" {
  name               = var.application_load_balancer_name
  internal           = false                      # Public-facing ALB
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ssh_access.id]
  subnets            = data.aws_subnets.filtered_subnets.ids
}

# Target group for ALB
resource "aws_lb_target_group" "assignment_tg" {
  name     = "assignment-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  stickiness {
    type    = "lb_cookie"
    enabled = false  # No stickiness — requests distributed round-robin
  }

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Attach EC2 instances to target group
resource "aws_lb_target_group_attachment" "tg_attachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.assignment_tg.arn
  target_id        = aws_instance.ubuntu_server[count.index].id
  port             = 80
}

############################################
# HTTPS Listener for ALB using ACM cert
############################################
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.assignment_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:ap-south-1:975050221465:certificate/ac378a26-09f2-4dbf-86ee-21061d0a471f"  # ✅ ACM cert ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.assignment_tg.arn
  }
}

########################################
# Route 53 A record for the ALB
########################################
data "aws_route53_zone" "gokulang" {
  name         = "gokulang.com."
  private_zone = false
}

resource "aws_route53_record" "gokulang_root" {
  zone_id = data.aws_route53_zone.gokulang.zone_id
  name    = "gokulang.com"
  type    = "A"

  alias {
    name                   = aws_lb.assignment_lb.dns_name
    zone_id                = aws_lb.assignment_lb.zone_id
    evaluate_target_health = true
  }
}
