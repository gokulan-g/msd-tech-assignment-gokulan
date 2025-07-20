output "alb_dns_name" {
  description = "ALB public DNS name"
  value       = aws_lb.assignment_lb.dns_name
}

output "instance_names" {
  description = "Names of the EC2 instances"
  value       = [for instance in aws_instance.ubuntu_server : instance.tags.Name]
}

output "instance_public_ips" {
  description = "Public IPs of EC2 instances"
  value       = [for instance in aws_instance.ubuntu_server : instance.public_ip]
}

output "postgres_endpoint" {
  value = aws_db_instance.postgres.endpoint
  description = "The DNS endpoint of the PostgreSQL RDS instance"
}


output "website_url" {
  value = "https://gokulang.com"
}
