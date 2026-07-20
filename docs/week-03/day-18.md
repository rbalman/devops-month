# Day 4 · AWS II — Networking, Load Balancing & Storage

> One server is a single point of failure. Today you build the shape of a real web tier: a **VPC** (your own private slice of the AWS network — the Week 2 networking concepts, now in the cloud), two instances across **availability zones**, an **Application Load Balancer** spreading traffic between them, and **S3** for object storage and static hosting. This is the "Go Live" architecture that survives a node — or a whole AZ — going down.

!!! danger "Load balancers are NOT free tier"
    An ALB costs roughly **$0.02–0.03/hour** plus data processing — a few cents for a lab, but **dollars if you leave it running for days**. Same for NAT gateways and idle Elastic IPs. Do the lab in one sitting and run the **teardown** at the end.

## Learning Objectives

- Explain a **VPC**, subnets, route tables, and the internet gateway — cloud networking
- Distinguish **public** vs **private** subnets
- Put two instances behind an **Application Load Balancer** with a **target group** and health checks
- Understand **Auto Scaling** groups conceptually
- Use **S3** for object storage and static website hosting
- Tear the whole stack down

---

## Prerequisites

- Day 3 complete (IAM user, CLI configured, key pair habits)
- A billing alarm active

---

## Theory · ~20 min

### 1. VPC — your private network in the cloud

A **VPC** (Virtual Private Cloud) is an isolated network you control, defined by a **CIDR block** (e.g. `10.0.0.0/16` — exactly the RFC 1918 ranges from Week 2). Inside it you carve **subnets**, one per availability zone. Every account starts with a **default VPC** so instances "just work," but knowing the pieces matters:

| Piece | Job |
|---|---|
| **VPC** | The overall private network (`10.0.0.0/16`) |
| **Subnet** | A slice in one AZ (`10.0.1.0/24`) |
| **Route table** | Where traffic for a destination goes |
| **Internet Gateway (IGW)** | The door to the public internet |
| **NAT Gateway** | Lets *private* subnets reach out without being reachable |

!!! tip "📺 Watch — *AWS Networking Basics: VPC & Subnets* (KodeKloud, ~18 min)"
    A reputable, chaptered tour of the VPC pieces above.

    [![AWS VPC & Subnets](https://img.youtube.com/vi/QM63dyA_4Pc/hqdefault.jpg){ width="360" }](https://youtu.be/QM63dyA_4Pc)

    **Chapters:** [what is a VPC](https://youtu.be/QM63dyA_4Pc?t=54) · [subnets: public vs private](https://youtu.be/QM63dyA_4Pc?t=347) · [internet gateway vs NAT](https://youtu.be/QM63dyA_4Pc?t=711)

### 2. Public vs private subnets

The only real difference: a **public** subnet's route table sends `0.0.0.0/0` to the **internet gateway**; a **private** subnet does not (it uses a NAT gateway for outbound-only). Web/load balancers live in public subnets; databases live in private ones. Isolation by topology — the same idea as Week 2's reverse-proxy-in-front pattern.

### 3. Load balancers

An **Application Load Balancer (ALB)** sits in front of your instances and distributes HTTP(S) requests. Its parts:

- **Listener** — what port the ALB accepts on (80/443).
- **Target group** — the pool of instances it forwards to, with a **health check** (e.g. `GET /` every 30s). Unhealthy targets are pulled out automatically.
- **Cross-AZ** — targets in multiple AZs mean one zone can fail and traffic keeps flowing.

This is the managed, cloud-scale version of the nginx round-robin you built in Week 2 · Day 4.

### 4. Auto Scaling (concept)

An **Auto Scaling Group (ASG)** launches/terminates instances to match demand or replace failures, using a **launch template** (the AMI + type + security group) and a target size. Paired with an ALB, it's how production web tiers self-heal and scale. (We'll wire the ALB by hand today; ASG is your stretch goal.)

### 5. S3 — object storage

**S3** stores **objects** (files) in **buckets** (globally-unique names). It's not a filesystem — it's a flat key→object store reached over HTTP, used for backups, artifacts, data lakes, and **static website hosting**. Access is denied by default; you open it deliberately with bucket policies.

---

## Lab · ~50 min

Using the **default VPC** keeps this focused on the load balancer and S3. (Building a VPC from scratch is the assignment.)

### Step 1 — Two instances in different AZs

```bash
# Reuse the AMI lookup + key pair + a web security group (port 80 from anywhere, 22 from your IP)
# Launch two t3.micro instances tagged golive-web, each with user-data that installs nginx
# and writes its hostname to the homepage:
cat > userdata.sh << 'EOF'
#!/bin/bash
apt-get update -q && apt-get install -y nginx
echo "<h1>$(hostname -f)</h1>" > /var/www/html/index.html
EOF

for AZ in a b; do
  aws ec2 run-instances --image-id $AMI --instance-type t3.micro \
    --key-name golive --security-group-ids $SG \
    --placement AvailabilityZone=${REGION}${AZ} \
    --user-data file://userdata.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=golive-web}]'
done
```

### Step 2 — Create the load balancer (console is clearest here)

1. **EC2 → Load Balancers → Create → Application Load Balancer** `golive-alb`, internet-facing, pick **two subnets in different AZs**.
2. **Create a target group** `golive-tg` (type: instances, protocol HTTP:80, health check path `/`), **register both instances**.
3. Point the ALB's **HTTP:80 listener** at `golive-tg`.

### Step 3 — Watch it balance

```bash
# Grab the ALB DNS name
aws elbv2 describe-load-balancers --names golive-alb \
  --query 'LoadBalancers[0].DNSName' --output text

# Hit it repeatedly — the hostname flips between the two instances
for i in $(seq 1 6); do curl -s http://<alb-dns-name>; done
```

Health-check drill: stop nginx on one instance (`sudo systemctl stop nginx`), watch the target group mark it **unhealthy**, and confirm all traffic shifts to the survivor.

### Step 4 — S3 static site

```bash
BUCKET=golive-static-$(date +%s)        # must be globally unique
aws s3 mb s3://$BUCKET
echo "<h1>Go Live static assets</h1>" > index.html
aws s3 cp index.html s3://$BUCKET/
aws s3 website s3://$BUCKET/ --index-document index.html
# (open bucket policy for public read — see the console "Static website hosting" panel)
aws s3 ls s3://$BUCKET
```

### Step 5 — 🔻 Teardown checklist

```bash
# 1. Delete the listener + load balancer
aws elbv2 delete-load-balancer --load-balancer-arn <alb-arn>
# 2. Delete the target group (after the ALB is gone)
aws elbv2 delete-target-group --target-group-arn <tg-arn>
# 3. Terminate both instances
aws ec2 terminate-instances --instance-ids <id1> <id2>
# 4. Empty + delete the bucket
aws s3 rb s3://$BUCKET --force
# 5. Delete the security group
aws ec2 delete-security-group --group-id $SG
```

Confirm in the console that **Load Balancers** and **Instances** are empty. The ALB is the line item that costs money — verify it's gone.

---

## Advanced Topics

- **Custom VPC** — build `10.0.0.0/16` with public + private subnets, an IGW, and route tables by hand (the assignment).
- **HTTPS on the ALB** — attach an ACM certificate to a 443 listener; the ALB terminates TLS (the managed version of Week 2's nginx TLS).
- **Auto Scaling Group** — a launch template + ASG behind the target group so capacity self-adjusts.
- **S3 storage classes & lifecycle** — Standard → Infrequent Access → Glacier for cost, with lifecycle rules to transition automatically.

---

## Assignment

1. **Build a VPC from scratch.** Create `10.0.0.0/16` with two public subnets (one per AZ), an internet gateway, and a route table sending `0.0.0.0/0` to the IGW. Launch an instance into it and SSH in. Submit the CLI/console steps and a diagram.
2. **Add Auto Scaling.** Put your two web instances behind an ASG (min 2, max 4) attached to the target group. Terminate one instance manually and show the ASG replacing it.
3. **Cost accounting.** From the Billing console, report what your ALB + instances cost during the lab, and list which resources here are free-tier vs paid.

---

## Further Reading

**Watch**

- 📺 [AWS Networking Basics: VPC & Subnets](https://youtu.be/QM63dyA_4Pc) (KodeKloud) — VPC, subnets, routing, gateways, chaptered

**Reference**

- [AWS — VPC concepts](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [AWS — Application Load Balancers](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [AWS — Auto Scaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/what-is-amazon-ec2-auto-scaling.html)
- [AWS — S3 static website hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
