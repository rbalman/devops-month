# Day 3 · AWS I — Identity & Compute (IAM + EC2)

> You've configured servers you own (Vagrant boxes). Now the servers live in **someone else's data center** — the cloud. Today you meet **AWS**: first **IAM** (who is allowed to do what — the foundation everything else rests on), then **EC2** (virtual machines), **security groups** (cloud firewalls), **AMIs** (machine images), and **key pairs**. The payoff: at the end you'll take *yesterday's Ansible playbook* and run it against a real EC2 instance — proving the skills transfer with zero changes.

!!! warning "This week costs real money if you're careless"
    Everything today fits in the **AWS Free Tier** (`t2.micro`/`t3.micro`, 750 hrs/month for 12 months). But an instance left running, or an unattached Elastic IP, *will* bill you. **Every AWS lab ends with a teardown checklist — do not skip it.** Set a billing alarm before you start.

## Learning Objectives

- Navigate **regions** and **availability zones** and configure the **AWS CLI**
- Model access with **IAM** — users, groups, roles, and policies (**least privilege**)
- Launch, inspect, and terminate an **EC2** instance
- Control traffic with **security groups**; understand **AMIs**, instance types, and **EBS**
- Re-target your Day 2 Ansible playbook at a cloud host
- **Tear down** everything you created

---

## Prerequisites

- An **AWS account** (credit card required; free tier covers this week)
- The Day 2 Ansible project on your control node (for the callback)
- A billing alarm (Billing → Budgets → create a $1 alert)

---

## Theory · ~20 min

### 1. Regions & availability zones

AWS runs in **regions** (geographic areas, e.g. `us-east-1`, `ap-south-1`), each containing multiple isolated **availability zones** (AZs, e.g. `us-east-1a`). You pick a region close to your users; spreading resources across AZs is how you survive a data-center failure. Most resources are **region-scoped** — an instance in `us-east-1` is invisible from the `eu-west-1` console.

### 2. IAM — identity and access management

IAM is the **gatekeeper**. Four concepts:

| Concept | What it is |
|---|---|
| **User** | A person or app with long-lived credentials |
| **Group** | A named set of users; attach policies once, apply to all |
| **Policy** | A JSON document listing allowed/denied **actions** on **resources** |
| **Role** | Temporary permissions *assumed* by a service or user — no stored password |

**Least privilege**: grant only what's needed. Your **root** account should be locked away (MFA, never used day-to-day); do everything as an IAM user.

A policy is just JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["ec2:DescribeInstances", "ec2:StartInstances"],
    "Resource": "*"
  }]
}
```

**Roles** matter most in the cloud: instead of putting AWS keys *on* an EC2 instance, you attach a **role** and the instance gets rotating temporary credentials automatically.

!!! tip "📺 Watch — *AWS IAM Explained for Beginners* (~23 min)"
    A chaptered walkthrough of exactly this section — users, groups, policies, and roles.

    [![AWS IAM Explained for Beginners](https://img.youtube.com/vi/B-MwKnNBh5s/hqdefault.jpg){ width="360" }](https://youtu.be/B-MwKnNBh5s)

    **Chapters:** [what is IAM](https://youtu.be/B-MwKnNBh5s?t=49) · [create a user](https://youtu.be/B-MwKnNBh5s?t=276) · [attach policies](https://youtu.be/B-MwKnNBh5s?t=590) · [groups](https://youtu.be/B-MwKnNBh5s?t=754) · [roles](https://youtu.be/B-MwKnNBh5s?t=950) · [assume a role](https://youtu.be/B-MwKnNBh5s?t=1214)

### 3. EC2 — elastic compute

**EC2** is virtual machines on demand. To launch one you choose:

- **AMI** (Amazon Machine Image) — the OS template (e.g. Ubuntu 22.04). You can build your own "golden AMI" with your software baked in.
- **Instance type** — the size (`t2.micro` = 1 vCPU / 1 GB, free-tier eligible).
- **Key pair** — an SSH keypair; AWS stores the public key, you keep the private `.pem`.
- **Security group** — the firewall (below).
- **Storage** — an **EBS** volume (network-attached virtual disk) that persists independently of the instance.

### 4. Security groups

A **security group** is a stateful virtual firewall attached to an instance. You write **inbound** rules (outbound is allow-all by default); replies to allowed connections come back automatically — the same statefulness you saw with `ufw` in Week 2. Rule of thumb: open **22** (SSH) only to your IP, **80/443** to the world.

### 5. The AWS CLI

The console is for learning; the **CLI** is for real work (and what Ansible/Terraform use under the hood). It authenticates with an IAM user's **access key**:

```bash
aws configure          # paste Access Key ID + Secret, set region + output=json
aws sts get-caller-identity   # confirm who you are
```

---

## Lab · ~50 min

### Step 1 — Create an IAM user and group (console)

1. **IAM → User groups → Create group** `devops`; attach the AWS-managed policy **`AmazonEC2FullAccess`** (fine for a lab).
2. **IAM → Users → Create user** `you-devops`, add to the `devops` group.
3. On the user, **Security credentials → Create access key** (CLI use-case). Save the key ID and secret.

### Step 2 — Configure the CLI

```bash
aws configure        # region e.g. us-east-1, output json
aws sts get-caller-identity      # should print your user ARN
```

### Step 3 — Key pair and security group

```bash
# SSH key pair (AWS keeps the public half)
aws ec2 create-key-pair --key-name golive --query 'KeyMaterial' \
  --output text > golive.pem && chmod 400 golive.pem

# Security group: SSH from your IP only, HTTP from anywhere
MYIP=$(curl -s https://checkip.amazonaws.com)
aws ec2 create-security-group --group-name golive-sg \
  --description "Go Live lab" --query 'GroupId' --output text
# (note the returned sg-xxxx; use it below)
SG=sg-xxxxxxxx
aws ec2 authorize-security-group-ingress --group-id $SG \
  --protocol tcp --port 22 --cidr ${MYIP}/32
aws ec2 authorize-security-group-ingress --group-id $SG \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
```

### Step 4 — Launch an EC2 instance

```bash
# Latest Ubuntu 22.04 AMI for your region
AMI=$(aws ec2 describe-images --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)

aws ec2 run-instances --image-id $AMI --instance-type t3.micro \
  --key-name golive --security-group-ids $SG \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=golive-web}]' \
  --query 'Instances[0].InstanceId' --output text
# wait ~30s, then get the public IP:
aws ec2 describe-instances --filters "Name=tag:Name,Values=golive-web" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

SSH in to confirm:

```bash
ssh -i golive.pem ubuntu@<public-ip>
exit
```

### Step 5 — The payoff: point Ansible at EC2

Ansible doesn't care whether a host is a Vagrant box or an EC2 instance — it's all SSH. On your **control node** (or wherever your Day 2 project lives), add the cloud host:

```ini
# inventory-aws.ini
[web]
golive-web ansible_host=<public-ip> ansible_user=ubuntu ansible_ssh_private_key_file=./golive.pem
```

```bash
ansible-playbook -i inventory-aws.ini site.yml      # yesterday's role, cloud target
curl http://<public-ip>                              # your templated homepage, in the cloud
```

Same playbook. Same result. That's the whole point of configuration management.

### Step 6 — 🔻 Teardown checklist

```bash
# Terminate the instance
aws ec2 terminate-instances --instance-ids <instance-id>
# Delete the security group (after the instance is gone)
aws ec2 delete-security-group --group-id $SG
# Delete the key pair
aws ec2 delete-key-pair --key-name golive
```

Then in the console, confirm **EC2 → Instances** shows *terminated* and no volumes linger under **EC2 → Volumes**.

---

## Advanced Topics

- **Instance roles** — attach an IAM role to EC2 so code on it calls AWS with no stored keys (you'll rely on this pattern constantly).
- **User data** — a startup script passed at launch (`--user-data`) that bootstraps the instance — a lightweight alternative to config management for first-boot setup.
- **Spot & reserved** — pricing models: spot for cheap interruptible compute, reserved/savings plans for steady workloads.
- **Golden AMIs** — bake configured images (with Packer) so instances boot ready-to-serve.

---

## Assignment

1. **Least-privilege policy.** Replace `AmazonEC2FullAccess` with a *custom* policy that allows only `ec2:Describe*` plus start/stop/terminate. Attach it, and show one command that now works and one that's denied.
2. **Two-tier security group.** Launch a second instance as a "database" that accepts port 5432 **only** from the web instance's security group (not the internet). Prove the web box can reach it and your laptop cannot.
3. **Reflect.** In 3–4 sentences: what did launching + configuring EC2 by hand reveal that Terraform (Days 6–7) will automate away?

---

## Further Reading

**Watch**

- 📺 [AWS IAM Explained for Beginners](https://youtu.be/B-MwKnNBh5s) (CodeSnippet) — users, groups, roles & policies, chaptered

**Reference**

- [AWS — What is IAM?](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
- [AWS — Amazon EC2](https://docs.aws.amazon.com/ec2/)
- [AWS CLI reference](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html)
- [AWS Free Tier](https://aws.amazon.com/free/) — know what's covered before you click
