# AWS Infrastructure as Code — Terraform Project

Provisions a production-ready AWS setup: **VPC → EC2 → RDS** using Terraform.

## Architecture

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
┌─────────────────────────── VPC (10.0.0.0/16) ─────────────────────────────┐
│                                                                              │
│  ┌──────────── Public Subnet (10.0.1.0/24) ────────────┐                   │
│  │  EC2 App Server (t3.micro)    NAT Gateway           │                   │
│  └──────────────────────────────────────────────────────┘                   │
│                                                                              │
│  ┌─── Private Subnet 1 ───┐    ┌─── Private Subnet 2 ───┐                  │
│  │  RDS Primary            │    │  RDS Standby (Multi-AZ) │                 │
│  └─────────────────────────┘    └─────────────────────────┘                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
terraform-aws-iac/
├── main.tf              # Provider + remote state backend
├── variables.tf         # All input variables
├── vpc.tf               # VPC, subnets, IGW, NAT, route tables
├── security_groups.tf   # EC2 and RDS security groups
├── ec2.tf               # EC2 instance, IAM role, AMI data source
├── rds.tf               # RDS PostgreSQL, subnet group, param group
├── outputs.tf           # Key values printed after apply
├── terraform.tfvars.example  # Example variable values
└── .gitignore
```

## Prerequisites

1. [Install Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0
2. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
3. Configure AWS credentials:
   ```bash
   aws configure
   # or use environment variables:
   export AWS_ACCESS_KEY_ID="..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_DEFAULT_REGION="us-east-1"
   ```

## Quick Start

### 1. Clone and configure
```bash
git clone <your-repo>
cd terraform-aws-iac

# Copy the example vars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (never commit this file!)
```

### 2. Set the DB password securely (never hardcode passwords)
```bash
export TF_VAR_db_password="YourStrongPassword123!"
```

### 3. Initialize Terraform
```bash
terraform init
```
Downloads the AWS provider (~100 MB) and sets up the working directory.

### 4. Preview what will be created
```bash
terraform plan
```
Terraform shows a diff of resources to create/update/destroy. **Always review before applying.**

### 5. Apply (create infrastructure)
```bash
terraform apply
# Type "yes" when prompted

# Or skip the confirmation prompt:
terraform apply -auto-approve
```

### 6. View outputs
```bash
terraform output
terraform output ec2_public_ip    # Get a specific output
```

### 7. Destroy (clean up — avoids AWS charges)
```bash
terraform destroy
```

---

## State Management (Critical Concept)

Terraform uses a **state file** (`terraform.tfstate`) to track what resources it has created. This is the source of truth for your infrastructure.

### Why remote state matters
- **Local state** (`terraform.tfstate`) is fine for learning but breaks team collaboration
- Two people running `terraform apply` simultaneously against local state = duplicate resources, data corruption
- Remote state in S3 + DynamoDB locking solves this

### Setting up remote state (S3 backend)

**Step 1** — Create the S3 bucket and DynamoDB table (do this once, manually or with a separate Terraform config):
```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket your-tf-state-bucket-UNIQUE \
  --region us-east-1

# Enable versioning (lets you roll back to previous state)
aws s3api put-bucket-versioning \
  --bucket your-tf-state-bucket-UNIQUE \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-tf-state-bucket-UNIQUE \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Step 2** — Uncomment the `backend "s3"` block in `main.tf`:
```hcl
backend "s3" {
  bucket         = "your-tf-state-bucket-UNIQUE"
  key            = "aws-iac-project/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

**Step 3** — Migrate local state to remote:
```bash
terraform init -reconfigure
# Terraform will ask: "Do you want to copy existing state to the new backend?" → yes
```

### State commands you need to know
```bash
terraform state list                        # List all managed resources
terraform state show aws_instance.app_server  # Inspect a specific resource
terraform state rm aws_instance.app_server  # Remove from state (does NOT delete the real resource)
terraform import aws_instance.app_server i-1234567890  # Import an existing resource into state
```

---

## Useful Terraform Commands

| Command | What it does |
|---------|-------------|
| `terraform init` | Download providers, set up backend |
| `terraform validate` | Check syntax without connecting to AWS |
| `terraform fmt` | Auto-format all .tf files |
| `terraform plan` | Preview changes |
| `terraform plan -out=tfplan` | Save plan to file (run apply from file) |
| `terraform apply tfplan` | Apply a saved plan exactly |
| `terraform apply -target=aws_instance.app_server` | Apply only one resource |
| `terraform destroy -target=aws_db_instance.main` | Destroy only one resource |
| `terraform output -json` | Output all values as JSON |
| `terraform graph` | Generate dependency graph (pipe to Graphviz) |

---

## Key Concepts Demonstrated

### 1. Modules and Resource Dependencies
Terraform builds an implicit dependency graph. Example:
```
RDS → depends on → DB Subnet Group → depends on → Private Subnets → depends on → VPC
```
You don't need to specify order — Terraform figures it out from references.

### 2. Data Sources
`data "aws_ami"` fetches the latest Amazon Linux 2 AMI dynamically:
```hcl
ami = data.aws_ami.amazon_linux_2.id  # Always current, no hardcoded AMI IDs
```

### 3. Count and Splat
```hcl
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)  # Creates N subnets from a list
  cidr_block = var.private_subnet_cidrs[count.index]
}

subnet_ids = aws_subnet.private[*].id  # [*] = get all IDs as a list
```

### 4. Sensitive Variables
```hcl
variable "db_password" {
  sensitive = true  # Terraform redacts this in plan/apply output
}
```
Always pass secrets via environment variables: `export TF_VAR_db_password="..."`

### 5. Lifecycle Rules
```hcl
disable_api_termination = var.environment == "prod" ? true : false
deletion_protection     = var.environment == "prod" ? true : false
```

---

## Security Checklist

- [ ] RDS is in private subnets with `publicly_accessible = false`
- [ ] RDS security group only allows traffic from the EC2 security group (not 0.0.0.0/0)
- [ ] `rds.force_ssl = 1` in the parameter group
- [ ] EBS root volume is encrypted (`encrypted = true`)
- [ ] RDS storage is encrypted (`storage_encrypted = true`)
- [ ] `terraform.tfvars` is in `.gitignore`
- [ ] DB password comes from env var, not the code
- [ ] `deletion_protection = true` for production RDS
- [ ] SSH CIDR restricted to your IP in production

---

## Estimated AWS Costs (us-east-1, dev settings)

| Resource | Monthly cost |
|----------|-------------|
| EC2 t3.micro | ~$8.50 |
| RDS db.t3.micro | ~$13.00 |
| NAT Gateway | ~$32.00 + data transfer |
| EIP (attached) | $0.00 |
| **Total** | **~$55/month** |

> NAT Gateway is the expensive part. For a learning environment, consider skipping it and using SSM Session Manager instead. Destroy resources when not in use.
