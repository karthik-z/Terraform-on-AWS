###############################################################
# rds.tf  –  RDS PostgreSQL instance, subnet group, param group
###############################################################

# ─── DB Subnet Group ───────────────────────────────────────
# RDS requires a subnet group spanning at least 2 AZs (for Multi-AZ)
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Private subnets for RDS"
  subnet_ids  = aws_subnet.private[*].id  # Splat expression → all private subnet IDs

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# ─── DB Parameter Group ────────────────────────────────────
# Lets you tune PostgreSQL settings without a restart (most params are dynamic)
resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-pg15-params"
  family      = "postgres15"
  description = "Custom parameter group for PostgreSQL 15"

  # Example: Force SSL connections — important security setting
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Log slow queries (anything over 1 second)
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name = "${var.project_name}-pg15-params"
  }
}

# ─── RDS Instance ──────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  # Engine
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 3  # Enable storage autoscaling up to 3x
  storage_type          = "gp3"
  storage_encrypted     = true  # Encrypt at rest — always enable this

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # NEVER expose RDS to the public internet

  # Configuration
  parameter_group_name = aws_db_parameter_group.main.name
  multi_az             = var.db_multi_az  # Set to true in production for HA

  # Backups — keep 7 days of automated backups
  backup_retention_period = 7
  backup_window           = "03:00-04:00"        # UTC — pick a low-traffic window
  maintenance_window      = "mon:04:00-mon:05:00" # Minor version upgrades happen here

  # Protect against accidental deletion in production
  deletion_protection      = var.environment == "prod" ? true : false
  skip_final_snapshot      = var.environment != "prod"  # Always snapshot in prod
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-final-snapshot" : null

  # Performance insights (free tier: 7-day retention)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Auto minor version upgrades (patch releases — safe to enable)
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-db"
  }
}
