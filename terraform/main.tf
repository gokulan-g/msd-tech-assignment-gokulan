resource "aws_security_group" "connect_to_rds" {
  name        = "connect-to-rds"
  description = "Allow access on port 5432"

  ingress {
    description = "Allow PostgreSQL from anywhere"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    description = "Allow PostgreSQL from anywhere"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  tags = {
    Name = "connect-to-rds"
  }

}

data "aws_rds_engine_version" "postgres_latest" {
  engine = "postgres"
}


resource "aws_db_instance" "postgres" {
  identifier                   = "msd-assignment-db"
  engine                       = "postgres"
  engine_version               =  data.aws_rds_engine_version.postgres_latest.version #"17.5"
  instance_class               = "db.t4g.micro"
  allocated_storage            = 20
  storage_type                 = "gp2"
  storage_encrypted            = false
  db_name                      = "mydb"
  username                     = "postgres"
  password                     = var.db_password                
  publicly_accessible          = true                             # 🌍 Make public
  multi_az                     = false
  vpc_security_group_ids       = [aws_security_group.connect_to_rds.id]
  skip_final_snapshot          = true
  deletion_protection          = false
  backup_retention_period      = 0
  auto_minor_version_upgrade   = false
  performance_insights_enabled = false
  copy_tags_to_snapshot        = false
}


############## working #######################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

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
    values = ["ap-south-1a", "ap-south-1b"]
  }
}

resource "aws_security_group" "ssh_access" {
  name        = "allow_ssh"
  description = "Allow SSH and HTTP/HTTPS inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ubuntu_server" {
  count         = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "msd_assignment_key"

  subnet_id              = element(data.aws_subnets.filtered_subnets.ids, count.index)
  vpc_security_group_ids = [aws_security_group.ssh_access.id]

  tags = {
    Name = "UbuntuWebServer${count.index + 1}"
  }
}

resource "aws_lb" "assignment_lb" {
  name               = "assignment-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ssh_access.id]
  subnets            = data.aws_subnets.filtered_subnets.ids
}

resource "aws_lb_target_group" "assignment_tg" {
  name     = "assignment-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  stickiness {
    type            = "lb_cookie"
    enabled         = false
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

resource "aws_lb_target_group_attachment" "tg_attachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.assignment_tg.arn
  target_id        = aws_instance.ubuntu_server[count.index].id
  port             = 80
}

# HTTPS Listener (replaces HTTP)
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.assignment_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:ap-south-1:975050221465:certificate/ac378a26-09f2-4dbf-86ee-21061d0a471f"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.assignment_tg.arn
  }
}

####### route 53 ###########################

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
