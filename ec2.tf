###############################################################
# ec2.tf  –  EC2 instance + dynamic AMI lookup
###############################################################

# ─── Data Source: Latest Amazon Linux 2 AMI ───────────────
# This always fetches the most recent Amazon Linux 2 AMI for your region.
# No more hardcoding AMI IDs that go stale!
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── EC2 Instance ──────────────────────────────────────────
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  # Attach the IAM role so EC2 can call AWS APIs (e.g., SSM, S3)
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # EBS root volume — encrypted by default
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  # User data runs once on first boot — installs a basic web server
  user_data = <<-EOF
    #!/bin/bash
    set -e
    yum update -y
    yum install -y httpd postgresql
    systemctl start httpd
    systemctl enable httpd

    # Write a simple status page
    cat > /var/www/html/index.html <<HTML
    <h1>IaC Demo Server</h1>
    <p>Provisioned by Terraform | $(hostname -f)</p>
    HTML

    echo "Bootstrap complete" >> /var/log/user-data.log
  EOF

  # Prevent accidental termination in production
  disable_api_termination = var.environment == "prod" ? true : false

  tags = {
    Name = "${var.project_name}-app-server"
  }
}

# ─── IAM Role for EC2 ──────────────────────────────────────
# Allows SSM Session Manager (no SSH required!) and CloudWatch logs
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach AWS-managed policies for SSM and CloudWatch
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
