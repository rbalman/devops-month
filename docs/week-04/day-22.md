# Day 22 · AWS Basics I — IAM & EC2

## Learning Objectives

- Understand the core AWS services and the shared responsibility model
- Set up IAM users, policies, and roles securely
- Launch an EC2 instance and connect to it via SSH

---

## Theory · ~20 min

### Why AWS?

AWS (Amazon Web Services) is the largest cloud provider. As a DevOps engineer, knowing your way around AWS is a baseline expectation. Even if your company uses GCP or Azure, the concepts are identical — one platform transfers to the others.

Core principle: you rent compute, storage, and networking instead of buying physical hardware.

### The AWS Global Infrastructure

- **Regions** — geographic areas (e.g., `us-east-1`, `ap-south-1`, `eu-west-1`)
- **Availability Zones (AZs)** — isolated data centers within a region (e.g., `us-east-1a`, `us-east-1b`)
- **High availability** = distribute across multiple AZs

Always deploy in the region closest to your users.

### IAM — Identity and Access Management

IAM controls **who** can do **what** in your AWS account.

| Concept | Meaning |
|---|---|
| **Root account** | The account email — never use for daily work |
| **IAM User** | A person or service with long-term credentials |
| **IAM Group** | Collection of users sharing the same policies |
| **IAM Policy** | JSON document defining allowed/denied actions |
| **IAM Role** | Temporary identity assumed by EC2, Lambda, etc. |

The **principle of least privilege**: give only the permissions actually needed, nothing more.

### EC2 — Elastic Compute Cloud

EC2 is virtual servers in the cloud. Key concepts:

| Term | Meaning |
|---|---|
| **AMI** | Amazon Machine Image — the OS template for your instance |
| **Instance type** | Hardware spec: `t3.micro`, `m5.large`, `c5.4xlarge` |
| **Security Group** | Firewall rules — what traffic is allowed in/out |
| **Key pair** | SSH key pair for connecting to the instance |
| **Elastic IP** | Static public IP address |
| **User Data** | Script that runs on first boot (like Vagrant provisioner) |

---

## Lab · ~50 min

### Step 1 — Set up AWS CLI

```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws --version
```

### Step 2 — Create an IAM user (do this in the AWS Console)

1. Log into [console.aws.amazon.com](https://console.aws.amazon.com) as root
2. Go to **IAM** → **Users** → **Create user**
3. Username: `devops-month-user`
4. Attach policies: `AdministratorAccess` (for learning only — narrow this in production)
5. Create access keys: **Security credentials** tab → **Create access key** → CLI use case
6. Download the CSV

```bash
# Configure the CLI with your credentials
aws configure
# AWS Access Key ID: <from CSV>
# AWS Secret Access Key: <from CSV>
# Default region name: ap-south-1   (or your closest region)
# Default output format: json

# Verify
aws sts get-caller-identity
```

### Step 3 — Create a key pair

```bash
# Generate key pair in AWS and save the private key locally
aws ec2 create-key-pair \
    --key-name devops-month \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/devops-month-ec2.pem

chmod 400 ~/.ssh/devops-month-ec2.pem

# Verify
aws ec2 describe-key-pairs --key-names devops-month
```

### Step 4 — Create a Security Group

```bash
# Get your default VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" \
    --query 'Vpcs[0].VpcId' --output text)
echo "VPC ID: $VPC_ID"

# Create security group
SG_ID=$(aws ec2 create-security-group \
    --group-name devops-month-sg \
    --description "DevOps Month lab security group" \
    --vpc-id $VPC_ID \
    --query 'GroupId' --output text)
echo "Security Group ID: $SG_ID"

# Allow SSH (port 22) from your IP only
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp --port 22 --cidr "${MY_IP}/32"

# Allow HTTP (port 80) from anywhere
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp --port 80 --cidr 0.0.0.0/0

echo "Security group configured"
```

### Step 5 — Launch an EC2 instance

```bash
# Get the latest Ubuntu 22.04 AMI ID for your region
AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)
echo "AMI ID: $AMI_ID"

# Launch the instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t3.micro \
    --key-name devops-month \
    --security-group-ids $SG_ID \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=devops-month-lab}]' \
    --user-data '#!/bin/bash
apt-get update
apt-get install -y nginx
echo "<h1>Hello from EC2!</h1>" > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx' \
    --query 'Instances[0].InstanceId' \
    --output text)
echo "Instance ID: $INSTANCE_ID"

# Wait for it to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "Instance is running!"

# Get the public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
echo "Public IP: $PUBLIC_IP"

# SSH in
ssh -i ~/.ssh/devops-month-ec2.pem ubuntu@$PUBLIC_IP

# Inside the instance
uname -a
curl http://localhost
exit

# Test the web server from your machine
curl http://$PUBLIC_IP

# IMPORTANT: Stop the instance when done to avoid charges
aws ec2 stop-instances --instance-ids $INSTANCE_ID
```

---

## Assignment

1. What is the difference between an IAM user and an IAM role? Give an example of when you'd use each.
2. What does a Security Group do? What is the difference between inbound and outbound rules?
3. Why is it bad practice to use the AWS root account for daily operations?
4. What is the `t3.micro` instance type? How does it compare to `t3.small` and `t3.medium` in CPU and RAM?

Document the `$INSTANCE_ID`, `$SG_ID`, and `$PUBLIC_IP` — you'll need them on Day 25.

---

!!! warning "Cost"
    Always stop or terminate instances you're not actively using. A `t3.micro` costs ~$0.01/hour — small, but it adds up. Set a billing alert in the AWS Console under **Billing → Budgets**.

## Further Reading

- [AWS IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [EC2 instance types comparison](https://instances.vantage.sh/)
- [AWS Free Tier limits](https://aws.amazon.com/free/)
