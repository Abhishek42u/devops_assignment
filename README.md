# AWS DevOps Assignment

A production-ready web application deployed on AWS using Terraform, GitHub Actions, and CloudWatch.

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
   ├── EC2 (Flask app on port 5000)
   └── EC2 (Flask app on port 5000)

[SSM Session Manager] ── no SSH / no bastion host needed
[CloudWatch Agent]    ── logs + memory metrics
[SNS]                 ── email alerts on CPU/memory alarms

[S3 Bucket] ◄── private, not public
   │
[CloudFront] ── serves static assets over HTTPS
```

---

## Project Structure

```
.
├── terraform/
│   ├── main.tf             # Provider and Terraform version config
│   ├── variables.tf        # All configurable inputs
│   ├── outputs.tf          # ALB URL, CloudFront URL, S3 bucket name
│   ├── vpc.tf              # VPC, subnets, IGW, NAT Gateway, route tables
│   ├── security_groups.tf  # ALB SG (port 80 public) + App SG (port 5000 from ALB only)
│   ├── iam.tf              # EC2 IAM role: SSM + CloudWatch + S3 read
│   ├── alb.tf              # Application Load Balancer + Target Group + Listener
│   ├── asg.tf              # Launch Template + Auto Scaling Group + scaling policies
│   ├── cloudwatch.tf       # Log group + CPU/memory alarms + SNS alerts
│   └── s3_cloudfront.tf    # Private S3 bucket + CloudFront distribution (OAC)
├── app/
│   ├── app.py              # Flask "Hello World" web app
│   └── requirements.txt
├── scripts/
│   └── deploy.sh           # Script that runs on EC2 during deployment (via SSM)
└── .github/
    └── workflows/
        └── deploy.yml      # GitHub Actions: auto-deploy on push to main
```

---

## Prerequisites

- AWS account (free tier)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured (`aws configure`)
- GitHub account

---

## Step 1 — Create GitHub Repository

1. Create a **public** GitHub repo (e.g. `devops-assignment`)
2. Push all this code to the `main` branch

```bash
git init
git add .
git commit -m "initial commit"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

---

## Step 2 — Update Terraform Variables

Edit `terraform/variables.tf` and update these two values:

| Variable | What to change |
|---|---|
| `github_repo_url` | Your GitHub repo HTTPS URL |
| `alert_email` | Your email address for CloudWatch alerts |
| `ami_id` | Find latest Amazon Linux 2 AMI for your region (see below) |

**Find the latest Amazon Linux 2 AMI:**
```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
  --output text
```

---

## Step 3 — Deploy Infrastructure with Terraform

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

After `apply` completes, copy the output values — you'll need them in the next step:

```
alb_dns_name    = "http://devops-app-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
s3_bucket_name  = "devops-app-static-xxxx"
asg_name        = "devops-app-asg"
cloudfront_url  = "https://xxxxxxxxxxxx.cloudfront.net"
```

> Also check your email — **confirm the SNS subscription** to receive alarm emails.

---

## Step 4 — Add GitHub Actions Secrets

Go to your GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |

> Create a dedicated IAM user for CI/CD with these policies:
> - `AmazonSSMFullAccess`
> - `ElasticLoadBalancingReadOnly`
> - `AutoScalingReadOnlyAccess`
> - `AmazonS3FullAccess` (for static file uploads)

---

## Step 5 — Trigger a Deployment

Push any change to `main` to trigger the pipeline:

```bash
# Edit app/app.py then:
git add app/app.py
git commit -m "update app"
git push
```

GitHub Actions will:
1. Find all healthy EC2 instances in the ASG
2. Run `git pull + pip install + systemctl restart` on each via SSM
3. Verify the ALB health check returns HTTP 200

---

## Step 6 — Access Your App

Open the `alb_dns_name` output URL in your browser. You should see:

```
Hello from ip-10-0-11-xxx!
AWS DevOps Assignment — Flask app running on EC2 behind ALB + ASG
```

---

## Connecting to Instances (No SSH needed)

Use SSM Session Manager instead of SSH:

```bash
# List running instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=devops-app-app-server" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
  --output table

# Open a shell session
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
```

---

## Monitoring

| Resource | What it does |
|---|---|
| CloudWatch Log Group `/aws/ec2/devops-app` | Collects `/var/log/messages` from all instances |
| Alarm `devops-app-cpu-high` | Triggers scale-up + SNS email when CPU > 70% |
| Alarm `devops-app-cpu-low` | Triggers scale-down when CPU < 20% |
| Alarm `devops-app-memory-high` | Sends SNS email when memory > 80% |

View logs: **AWS Console → CloudWatch → Log groups → /aws/ec2/devops-app**

---

## Tear Down

To avoid AWS charges, destroy all resources when done:

```bash
cd terraform
terraform destroy
```

---

## Cost Estimate (Free Tier)

| Resource | Free Tier |
|---|---|
| EC2 t3.micro | 750 hrs/month free |
| ALB | ~$0.008/hour (not free) |
| NAT Gateway | ~$0.045/hour (not free) |
| S3 | 5 GB free |
| CloudFront | 1 TB transfer free |

> **Tip:** NAT Gateway and ALB are the main costs. Destroy when not testing.
