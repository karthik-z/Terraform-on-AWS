# 🏗️ AWS Infrastructure as Code — Terraform

> Provision a production-ready AWS environment (VPC + EC2 + RDS) using Terraform — fully automated, version-controlled, and repeatable.

![Terraform](https://img.shields.io/badge/Terraform-v1.6%2B-7B42BC?style=flat&logo=terraform)
![AWS](https://img.shields.io/badge/AWS-us--east--1-FF9900?style=flat&logo=amazon-aws)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15.17-4169E1?style=flat&logo=postgresql)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

---

## 🏛️ Architecture

```
                         Internet
                             │
                    ┌────────▼────────┐
                    │ Internet Gateway │
                    └────────┬────────┘
                             │
        ┌────────────────────▼──────────────────────────┐
        │              VPC  10.0.0.0/16                  │
        │                                                 │
        │  ┌──────────── Public Subnet 10.0.1.0/24 ────┐ │
        │  │                                            │ │
        │  │   ┌──────────────┐   ┌─────────────────┐  │ │
        │  │   │  EC2 t3.micro│   │   NAT Gateway   │  │ │
        │  │   │  Apache HTTP │   │   EIP assigned  │  │ │
        │  │   │  IAM Role    │   │                 │  │ │
        │  │   └──────┬───────┘   └────────┬────────┘  │ │
        │  └──────────┼────────────────────┼───────────┘ │
        │             │                    │              │
        │  ┌──────────▼──────┐  ┌──────────▼──────────┐  │
        │  │ Private Subnet 1│  │  Private Subnet 2   │  │
        │  │  10.0.2.0/24   │  │   10.0.3.0/24       │  │
        │  │  us-east-1a    │  │   us-east-1b        │  │
        │  │                │  │                     │  │
        │  │ ┌────────────┐ │  │  ┌───────────────┐  │  │
        │  │ │RDS Primary │ │  │  │ RDS Standby   │  │  │
        │  │ │postgres 15 │◄├──┼──►│ (Multi-AZ)   │  │  │
        │  │ │Encrypted   │ │  │  │ Auto-failover │  │  │
        │  │ └────────────┘ │  │  └───────────────┘  │  │
        │  └────────────────┘  └─────────────────────┘  │
        └────────────────────────────────────────────────┘
```

---

## ✨ Features

- **Custom VPC** with public and private subnets across 2 Availability Zones
- **EC2 Instance** (t3.micro) with encrypted EBS, IAM role, and bootstrap via `user_data`
- **RDS PostgreSQL 15** in private subnets — encrypted, automated backups, SSL enforced
- **NAT Gateway** for secure outbound-only access from private resources
- **Security Groups** using reference-based rules (EC2 SG → RDS SG, no open CIDRs)
- **IAM Role** with SSM Session Manager + CloudWatch — no SSH keys needed
- **Remote state ready** — S3 backend + DynamoDB locking (commented, easy to enable)
- **Auto-tagged** resources via `default_tags` in the provider block
- **Dynamic AMI** lookup — always uses the latest Amazon Linux 2, no hardcoded IDs

---

## 📁 Project Structure

```
terraform-aws-iac/
├── main.tf                   # Provider config + S3 backend (commented)
├── variables.tf              # All inputs — typed, validated, sensitive-flagged
├── vpc.tf                    # VPC, subnets, IGW, NAT Gateway, route tables
├── security_groups.tf        # EC2 and RDS security groups
├── ec2.tf                    # EC2 instance, IAM role, dynamic AMI data source
├── rds.tf                    # RDS PostgreSQL, subnet group, parameter group
├── outputs.tf                # Key values printed after apply
├── terraform.tfvars.example  # Template — copy to terraform.tfvars
└── .gitignore                # Excludes state files, .tfvars, .terraform/
```

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | ≥ 1.6.0 | [hashicorp.com/terraform](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | ≥ 2.x | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| AWS Account | — | IAM user with EC2, RDS, VPC permissions |

### 1. Clone the repo

```bash
git clone https://github.com/karthik-z/Terraform-on-AWS
cd Terraform-on-AWS
```

### 2. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars   # set project_name, environment, region
```

### 3. Set DB password securely (never hardcode it)

```bash
export TF_VAR_db_password="YourStrongPassword123!"
```

### 4. Deploy

```bash
terraform init       # download AWS provider
terraform validate   # check syntax
terraform fmt        # auto-format
terraform plan       # preview — always read this before applying
terraform apply      # create infrastructure (~10 min, RDS takes longest)
```

### 5. Access your resources

```bash
terraform output ec2_public_ip    # open in browser: http://<ip>
terraform output rds_endpoint     # postgres connection host
```

### 6. Clean up (avoid charges)

```bash
terraform destroy
```

---

## ⚙️ Configuration

All variables are defined in `variables.tf`. Key ones to set in `terraform.tfvars`:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region to deploy into |
| `project_name` | `aws-iac-demo` | Prefix for all resource names |
| `environment` | `dev` | One of: `dev`, `staging`, `prod` |
| `instance_type` | `t3.micro` | EC2 instance type |
| `db_engine_version` | `15.17` | PostgreSQL version |
| `db_instance_class` | `db.t3.micro` | RDS instance class |
| `db_multi_az` | `false` | Set `true` for production HA |

> `db_password` is intentionally excluded — always pass via `export TF_VAR_db_password="..."`

---

## 🔐 Security Highlights

- RDS lives in **private subnets** with `publicly_accessible = false`
- RDS security group only allows port 5432 **from the EC2 security group** (not from `0.0.0.0/0`)
- `rds.force_ssl = 1` enforced via parameter group
- EBS root volume encrypted at rest (`encrypted = true`)
- RDS storage encrypted (`storage_encrypted = true`)
- EC2 uses **IAM Instance Profile** — no long-lived credentials on the instance
- Secrets passed via environment variables — never stored in `.tf` files
- `terraform.tfvars` excluded via `.gitignore`

---

## 🗄️ State Management

By default, state is stored locally. For team use, uncomment the S3 backend in `main.tf`:

```hcl
backend "s3" {
  bucket         = "your-tf-state-bucket"
  key            = "Terraform-on-AWS/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

Create the prerequisites once:

```bash
# S3 bucket
aws s3api create-bucket --bucket your-tf-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-tf-state-bucket \
  --versioning-configuration Status=Enabled

# DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Then migrate: `terraform init -reconfigure`

---

## 💡 Key Terraform Concepts Demonstrated

### Dynamic AMI lookup (no hardcoded IDs)
```hcl
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

### Count + splat for multi-AZ subnets
```hcl
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
}

subnet_ids = aws_subnet.private[*].id  # all subnet IDs as a list
```

### Security group referencing (not CIDR)
```hcl
ingress {
  from_port       = 5432
  security_groups = [aws_security_group.ec2.id]  # reference, not "0.0.0.0/0"
}
```

### Environment-conditional settings
```hcl
deletion_protection     = var.environment == "prod" ? true : false
skip_final_snapshot     = var.environment != "prod"
disable_api_termination = var.environment == "prod" ? true : false
```

---

## 💰 Estimated Cost (us-east-1)

| Resource | Monthly |
|----------|---------|
| EC2 t3.micro | ~$8.50 |
| RDS db.t3.micro | ~$13.00 |
| NAT Gateway | ~$32.00 + data transfer |
| EIP (attached) | $0.00 |
| **Total** | **~$55/month** |

> For learning, always run `terraform destroy` when done. NAT Gateway costs ~$1/day even when idle.

---

## 🛠️ Useful Commands

```bash
terraform state list                              # list all tracked resources
terraform state show aws_instance.app_server      # inspect a resource
terraform output                                  # print all output values
terraform apply -target=aws_instance.app_server  # apply only one resource
terraform plan -out=tfplan                        # save plan to file
terraform apply tfplan                            # apply exact saved plan
terraform graph | dot -Tpng > graph.png           # visualize dependency graph
```

---

## 🗺️ Roadmap

- [ ] Add Application Load Balancer in front of EC2
- [ ] Convert to reusable Terraform modules
- [ ] Add CloudFront CDN distribution
- [ ] Set up CI/CD pipeline with GitHub Actions
- [ ] Add Auto Scaling Group for EC2
- [ ] Enable CloudWatch alarms and SNS notifications

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🙋 Author

**Karthik**
- Built and deployed this project hands-on, debugging real AWS errors end-to-end
- Skills: Terraform · AWS VPC · EC2 · RDS · IAM · State Management · Cloud Networking
