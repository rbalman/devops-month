# Day 23 · AWS Basics II — VPC, S3 & Security Groups

## Learning Objectives

- Understand VPC networking: subnets, route tables, and internet gateway
- Use S3 for object storage (upload, download, static hosting)
- Apply security group rules to control traffic precisely

---

## Theory · ~20 min

### VPC — Virtual Private Cloud

A VPC is your own isolated network within AWS. Think of it as your private data center network hosted in the cloud.

```
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24)   → has route to Internet Gateway
│   └── EC2 (public IP, internet-facing)
├── Private Subnet (10.0.2.0/24)  → no direct internet route
│   └── RDS Database (no public IP)
└── Internet Gateway               → connects VPC to the internet
```

Key components:

| Component | Role |
|---|---|
| **Subnet** | A range of IPs within the VPC (public or private) |
| **Internet Gateway (IGW)** | Allows VPC resources to reach the internet |
| **Route Table** | Rules for where to send traffic |
| **NAT Gateway** | Allows private subnet instances to reach internet (outbound only) |
| **Security Group** | Instance-level firewall (stateful) |
| **Network ACL** | Subnet-level firewall (stateless) |

### S3 — Simple Storage Service

S3 stores files (called **objects**) in containers called **buckets**. It's:
- Infinitely scalable — upload petabytes
- Highly durable — 99.999999999% durability (11 nines)
- Accessible via URL, CLI, or SDK

Common uses:
- Static website hosting
- Application file storage (uploads, exports)
- Terraform state backend
- Log archiving
- CI/CD artifact storage (Docker images, binaries)

---

## Lab · ~50 min

### Step 1 — Explore your default VPC

```bash
# List VPCs
aws ec2 describe-vpcs --output table

# Get default VPC details
aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query 'Vpcs[0]'

# List subnets in default VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" \
    --query 'Vpcs[0].VpcId' --output text)

aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}' \
    --output table
```

### Step 2 — Create a custom VPC (understanding the pieces)

```bash
# Create VPC
CUSTOM_VPC=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
    --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $CUSTOM_VPC --tags Key=Name,Value=devops-month-vpc

# Create public subnet
PUBLIC_SUBNET=$(aws ec2 create-subnet \
    --vpc-id $CUSTOM_VPC \
    --cidr-block 10.0.1.0/24 \
    --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PUBLIC_SUBNET --tags Key=Name,Value=public-subnet

# Create internet gateway
IGW=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $CUSTOM_VPC

# Create route table and add route to internet
RT=$(aws ec2 create-route-table --vpc-id $CUSTOM_VPC \
    --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW

# Associate route table with subnet
aws ec2 associate-route-table --route-table-id $RT --subnet-id $PUBLIC_SUBNET

echo "VPC: $CUSTOM_VPC"
echo "Subnet: $PUBLIC_SUBNET"
echo "IGW: $IGW"
```

### Step 3 — S3 basics

```bash
# Create a bucket (must be globally unique)
BUCKET_NAME="devops-month-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME
echo "Bucket: $BUCKET_NAME"

# Upload a file
echo "Hello from S3" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://$BUCKET_NAME/test.txt

# List contents
aws s3 ls s3://$BUCKET_NAME

# Download it
aws s3 cp s3://$BUCKET_NAME/test.txt /tmp/from-s3.txt
cat /tmp/from-s3.txt

# Sync a directory to S3
mkdir -p /tmp/site
echo "<h1>Static Site on S3</h1>" > /tmp/site/index.html
echo "<p>About page</p>" > /tmp/site/about.html

aws s3 sync /tmp/site s3://$BUCKET_NAME/site/
aws s3 ls s3://$BUCKET_NAME/site/
```

### Step 4 — S3 static website hosting

```bash
# Enable static website hosting
aws s3 website s3://$BUCKET_NAME \
    --index-document index.html \
    --error-document error.html

# Make the site folder public
aws s3api put-bucket-policy \
    --bucket $BUCKET_NAME \
    --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Principal\": \"*\",
            \"Action\": \"s3:GetObject\",
            \"Resource\": \"arn:aws:s3:::${BUCKET_NAME}/site/*\"
        }]
    }"

# Get the website endpoint
REGION=$(aws configure get region)
echo "Website URL: http://${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com/site/"
curl "http://${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com/site/"
```

### Step 5 — Security group deep dive

```bash
# Get your existing security group
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=devops-month-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)

# See current rules
aws ec2 describe-security-groups --group-ids $SG_ID \
    --query 'SecurityGroups[0].IpPermissions'

# Add a rule for port 443 (HTTPS)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp --port 443 --cidr 0.0.0.0/0

# Add a rule for port 8080 from your IP only
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp --port 8080 --cidr "${MY_IP}/32"

# Remove a rule
aws ec2 revoke-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp --port 8080 --cidr "${MY_IP}/32"

# Clean up custom VPC (so it doesn't clutter your account)
aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $CUSTOM_VPC
aws ec2 delete-internet-gateway --internet-gateway-id $IGW
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET
aws ec2 delete-route-table --route-table-id $RT
aws ec2 delete-vpc --vpc-id $CUSTOM_VPC
```

---

## Assignment

In `my-progress/day-23.md`:

1. What is the difference between a public subnet and a private subnet in AWS?
2. What is the difference between a Security Group and a Network ACL? Which is stateful?
3. Upload your `my-progress/` directory to S3 as a backup (`aws s3 sync my-progress/ s3://<bucket>/backup/`). Paste the command and the output.
4. Why would you store Terraform state in S3 instead of locally?

---

## Further Reading

- [AWS VPC documentation](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [S3 getting started](https://docs.aws.amazon.com/AmazonS3/latest/userguide/GetStartedWithS3.html)
- [VPC subnet sizing guide](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html)
