# AWS DevOps Assignment

A Flask web application deployed on AWS using Terraform (IaC), GitHub Actions (CI/CD), and CloudWatch (Monitoring).

---

## Architecture

```
Internet
   │
   ▼
[ALB] ── public subnets (us-east-1a, us-east-1b)
   │
   ▼
[Auto Scaling Group] ── private subnets (min:1, max:2, t3.micro)
   │
   └── EC2 instances (Flask app on port 5000)

[SSM Session Manager] ── shell access, no SSH / no bastion host
[CloudWatch Agent]    ── logs + memory metrics from EC2
[SNS]                 ── email alerts on CPU/memory alarms

[S3 Bucket] ◄── private, accessible only via CloudFront
   │
[CloudFront] ── serves static assets over HTTPS
```

---

## Project Structure

```
.
├── terraform/
│   ├── main.tf             # AWS provider + Terraform version
│   ├── variables.tf        # All configurable inputs
│   ├── outputs.tf          # ALB URL, CloudFront URL, S3 bucket name, ASG name
│   ├── vpc.tf              # VPC, public/private subnets, IGW, NAT Gateway, route tables
│   ├── security_groups.tf  # ALB SG (port 80) + App SG (port 5000 from ALB only)
│   ├── iam.tf              # EC2 IAM role: SSM + CloudWatch + S3 read
│   ├── alb.tf              # ALB + Target Group (health check on /health) + Listener
│   ├── asg.tf              # Launch Template (user_data bootstrap) + ASG + scaling policies
│   ├── cloudwatch.tf       # Log group + CPU/memory alarms + SNS topic + email subscription
│   └── s3_cloudfront.tf    # Private S3 bucket + CloudFront OAC distribution
├── app/
│   ├── app.py              # Flask app — serves / and /health endpoints
│   └── requirements.txt    # flask==2.2.5 (compatible with Python 3.7 on Amazon Linux 2)
├── scripts/
│   └── deploy.sh           # Runs on EC2 via SSM during CI/CD — git pull + restart
└── .github/
    └── workflows/
        └── deploy.yml      # GitHub Actions: triggers on push to main
```

---

## Prerequisites

- AWS account (free tier)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI v2](https://aws.amazon.com/cli/) — run `aws configure` after install
- [AWS SSM Session Manager Plugin](https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe) — required for `aws ssm start-session`
- GitHub account

---

## Deployment Steps

### Step 1 — Configure AWS CLI

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region (us-east-1), output (json)
```

Verify:
```bash
aws sts get-caller-identity
```

---

### Step 2 — Push Code to GitHub

Create a **public** repo on GitHub, then:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/Abhishek42u/devops_assignment.git
git push -u origin main
```

---

### Step 3 — Update Variables

Edit `terraform/variables.tf` and set:

| Variable | Value |
|---|---|
| `github_repo_url` | Your GitHub repo HTTPS URL |
| `alert_email` | Email address to receive CloudWatch alarm notifications |
| `ami_id` | Latest Amazon Linux 2 AMI ID for your region (see below) |

**Get the latest AMI ID:**
```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
  --output text
```

---

### Step 4 — Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Takes 10–15 minutes. Copy the output values when done:

```
alb_dns_name    = "http://devops-app-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
cloudfront_url  = "https://xxxxxxxxxxxx.cloudfront.net"
s3_bucket_name  = "devops-app-static-xxxxxxxx"
asg_name        = "devops-app-asg"
```

Check your email and **click "Confirm subscription"** in the AWS SNS email to enable alarm notifications.

---

### Step 5 — Add GitHub Actions Secrets

Go to your GitHub repo → **Settings → Secrets and variables → Actions**

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS IAM secret key |

---

### Step 6 — Test the App

Wait 5 minutes after `terraform apply` for EC2 to bootstrap, then open in browser:

```
http://<alb_dns_name>/health   → {"status": "ok"}
http://<alb_dns_name>          → Hello from <hostname> page
```

---

### Step 7 — Trigger CI/CD Pipeline

Push any change to `main`:

```bash
git add app/app.py
git commit -m "Update app"
git push origin main
```

Go to GitHub → **Actions** tab → watch the pipeline deploy automatically to EC2 via SSM.

---

## Connecting to EC2 (No SSH)

```bash
# Get instance ID
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names devops-app-asg \
  --query "AutoScalingGroups[0].Instances[*].InstanceId" \
  --output text

# Open shell session
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
```

---

## Monitoring

| Resource | Purpose |
|---|---|
| CloudWatch Log Group `/aws/ec2/devops-app` | EC2 system logs via CloudWatch Agent |
| Alarm `devops-app-cpu-high` | CPU > 70% → scale up + email |
| Alarm `devops-app-cpu-low` | CPU < 20% → scale down |
| Alarm `devops-app-memory-high` | Memory > 80% → email |

View logs: AWS Console → **CloudWatch → Log groups → /aws/ec2/devops-app**

---

## Static Content via CloudFront

```bash
# Upload a file to S3
aws s3 cp index.html s3://$(terraform output -raw s3_bucket_name)/index.html

# Access via CloudFront (direct S3 access is blocked)
terraform output cloudfront_url
```

---

## Tear Down

```bash
cd terraform
terraform destroy
```

---

## Cost Note (Free Tier)

| Resource | Cost |
|---|---|
| EC2 t3.micro | 750 hrs/month free |
| ALB | ~$0.008/hr — not free |
| NAT Gateway | ~$0.045/hr — not free |
| S3 + CloudFront | Mostly free under free tier |

Destroy resources after testing to avoid charges. ALB and NAT Gateway are the main cost drivers.
