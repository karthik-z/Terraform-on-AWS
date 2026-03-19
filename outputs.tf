###############################################################
# outputs.tf  –  Values printed after `terraform apply`
###############################################################

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 app server"
  value       = aws_instance.app_server.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS hostname of the EC2 app server"
  value       = aws_instance.app_server.public_dns
}

output "ec2_instance_id" {
  description = "EC2 instance ID (use for SSM Session Manager access)"
  value       = aws_instance.app_server.id
}

output "rds_endpoint" {
  description = "RDS connection endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "rds_db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.main.db_name
}

output "nat_gateway_ip" {
  description = "Elastic IP assigned to the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# ─── Connection strings (sensitive) ────────────────────────
output "ssh_command" {
  description = "SSH command to connect to EC2 (if a key pair was provided)"
  value       = var.key_pair_name != "" ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.app_server.public_ip}" : "No key pair provided — use SSM Session Manager"
}

output "db_connection_string" {
  description = "PostgreSQL connection string (password masked)"
  value       = "postgresql://${var.db_username}:***@${aws_db_instance.main.endpoint}/${var.db_name}"
  sensitive   = false  # Endpoint is not sensitive; password is already masked
}
