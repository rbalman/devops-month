# Day 4 · AWS II — Launch an EC2 Machine + IAM

> Yesterday you got oriented. Today you build the thing the cloud is famous for: a **virtual server on demand**. You'll launch an **EC2** instance — choosing its **AMI** (OS image), **instance type** (size), **key pair** (SSH access), storage, and the **VPC** it lands in — then SSH in. First a short stop at **IAM**, because *who is allowed to do what* is the foundation everything else sits on. The payoff comes in the assignment: you'll point an **Ansible playbook** at this real cloud host to deploy a website — proving your Week-3 skills transfer to the cloud with zero changes.

!!! warning "Free-tier, but only if you tear down"
    EC2 `t3.micro`/`t2.micro` is free-tier eligible (**750 hrs/month for 12 months**). But an instance left running past the free tier, or an unattached Elastic IP, *will* bill you. **This lab ends with a teardown checklist — do not skip it.**

## Learning Objectives

- Model access with **IAM** — users, groups, roles, policies (**least privilege**)
- Understand the EC2 building blocks: **AMI**, **instance type**, **key pair**, storage, **VPC**
- Launch a public, **SSH-accessible EC2 instance** and connect to it
- Deploy a website to it with **Ansible** (the assignment)
- **Tear down** what you created

---

## Prerequisites

- Day 3 complete (AWS account + billing alarm active)
- The Ansible project from **Week 3 · Day 1** on your control node (for the assignment)

---

## Theory · ~20 min

### 1. IAM — who can do what

Before you create resources, understand **IAM** (Identity and Access Management) — the gatekeeper for your whole account. Four concepts:

| Concept | What it is |
|---|---|
| **User** | A person or app with long-lived credentials (password and/or access key) |
| **Group** | A named set of users; attach a policy once, it applies to all members |
| **Policy** | A JSON document listing allowed/denied **actions** on **resources** |
| **Role** | Temporary permissions *assumed* by a service or user — no stored password |

**Least privilege**: grant only what's needed, nothing more. Your **root** user (from yesterday) stays locked away with MFA; you do daily work as an IAM user. A policy is just JSON:

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

**Roles** matter most in the cloud: instead of putting AWS keys *on* an EC2 instance, you attach a **role** and the instance receives rotating temporary credentials automatically.

!!! tip "📺 Watch — AWS IAM, explained"
    Users, groups, policies, and roles — the exact concepts above.

    [![AWS IAM explained](https://img.youtube.com/vi/hAk-7ImN6iM/hqdefault.jpg){ width="360" }](https://www.youtube.com/watch?v=hAk-7ImN6iM)

### 2. EC2 and its building blocks

**EC2** (Elastic Compute Cloud) is virtual machines on demand. To launch one you choose:

- **AMI** (Amazon Machine Image) — the OS template (e.g. Ubuntu 24.04). You can bake your own "golden AMI" with software pre-installed.
- **Instance type** — the size. `t3.micro` = 2 vCPU / 1 GB RAM, free-tier eligible. Families trade CPU/memory/network differently (`t` = burstable, `m` = balanced, `c` = compute, `r` = memory).
- **Key pair** — an SSH keypair. AWS stores the public key; you keep the private `.pem` to log in.
- **Security group** — the instance's stateful firewall. You write **inbound** rules (outbound is allow-all); "SSH enabled" just means a rule opening **port 22**. Same idea as `ufw` in Week 2.
- **VPC / subnet** — the network the instance lives in. Every account has a **default VPC** so instances "just work"; you'll build one from scratch on Day 5.
- **Storage** — an **EBS** volume (network-attached virtual SSD, e.g. **gp3**) that persists independently of the instance.

!!! tip "💰 Check the price before you launch"
    Instance types have very different hourly costs. Bookmark this pricing lookup and check any type before you use it — e.g. the `t3.micro` you'll launch today:

    👉 **[instances.vantage.sh/aws/ec2/t3.micro](https://instances.vantage.sh/aws/ec2/t3.micro)** — on-demand price, specs, and comparisons for every EC2 instance type.

!!! tip "📺 Watch — Launch an EC2 instance (AMI, type, key pair)"
    A full walkthrough of the launch flow you're about to do.

    [![Launch an EC2 instance](https://img.youtube.com/vi/5xc8M5WMM6s/hqdefault.jpg){ width="360" }](https://www.youtube.com/watch?v=5xc8M5WMM6s)

---

## Lab · ~25 min

Do this in the **console** — the launch wizard shows every EC2 building block in one place.

### Launch an EC2 instance

**EC2 → Instances → Launch instances**, then set:

| Setting | Value |
|---|---|
| **Name** | `golive-web` |
| **AMI** | **Ubuntu Server 24.04 LTS** (free-tier eligible) |
| **Instance type** | **`t3.micro`** |
| **Key pair** | Create a new key pair `golive` (RSA, `.pem`) — download and keep it |
| **Network** | **default VPC**, **Auto-assign public IP: Enable** (publicly accessible) |
| **Security group** | Create one with an **inbound SSH (22)** rule from your IP — this is "SSH enabled" |
| **Storage** | **8 GiB**, volume type **gp3** (SSD) |

Launch it, wait for **Instance state → Running**, copy the **Public IPv4 address**, and connect:

```bash
chmod 400 golive.pem
ssh -i golive.pem ubuntu@<public-ip>      # you're on a cloud server
exit
```

??? note "Prefer the CLI? The same launch in one block"
    ```bash
    # SSH key pair + a security group that opens port 22 to your IP
    aws ec2 create-key-pair --key-name golive --query 'KeyMaterial' \
      --output text > golive.pem && chmod 400 golive.pem
    MYIP=$(curl -s https://checkip.amazonaws.com)
    SG=$(aws ec2 create-security-group --group-name golive-sg \
      --description "Go Live" --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id $SG \
      --protocol tcp --port 22 --cidr ${MYIP}/32

    # Latest Ubuntu 24.04 AMI, t3.micro, public IP, 8 GiB gp3
    AMI=$(aws ec2 describe-images --owners 099720109477 \
      --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
      --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
    aws ec2 run-instances --image-id $AMI --instance-type t3.micro \
      --key-name golive --security-group-ids $SG --associate-public-ip-address \
      --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8,"VolumeType":"gp3"}}]' \
      --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=golive-web}]'
    ```

### 🔻 Teardown checklist

Keep the instance if you're doing the assignment next; otherwise tear it down now:

```bash
aws ec2 terminate-instances --instance-ids <instance-id>
aws ec2 delete-security-group --group-id <sg-id>     # after the instance is gone
aws ec2 delete-key-pair --key-name golive
```

Confirm **EC2 → Instances** shows *terminated* and no volumes linger under **EC2 → Volumes**.

---

## Advanced Topics

Adjacent to today — read the linked resource for each:

- **Instance roles (IAM roles for EC2)** — attach a role so code on the box calls AWS with no stored keys → [AWS — IAM roles for Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
- **User data** — a startup script passed at launch that bootstraps the instance on first boot → [AWS — Run commands at launch (user data)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- **Spot Instances** — cheap interruptible compute for fault-tolerant workloads → [AWS — Spot Instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html)
- **Golden AMIs with Packer** — bake configured images so instances boot ready-to-serve → [Packer — Build an AWS AMI](https://developer.hashicorp.com/packer/tutorials/aws-get-started/aws-get-started-build-image)

---

## Assignment

**Deploy a website to your EC2 instance with Ansible.** Reuse the `site.zip` from [Week 3 · Day 1 (Ansible I)](day-15.md) — same file, now hosted on a real cloud server.

1. Add an **inbound HTTP (80)** rule to the instance's security group (from anywhere).
2. Add the instance to an Ansible **inventory** — its public IP, `ansible_user=ubuntu`, and `ansible_ssh_private_key_file` pointing at your `golive.pem`.
3. Write a **playbook** targeting it that:
   - installs **nginx**,
   - downloads `site.zip` from `https://github.com/user-attachments/files/30199374/site.zip` with the **`get_url`** module,
   - extracts it into the web root `/var/www/html` with the **`unarchive`** module (`remote_src: true`),
   - ensures **nginx** is started and enabled.
4. Verify: `curl http://<public-ip>` (and a browser) returns the site.

**Tear down** the instance when you're done. This is the same playbook shape as the Day 1 Vagrant lab — pointed at the cloud instead. Same skills, real host.

---

## Further Reading

**Watch**

- 📺 [AWS IAM, explained](https://www.youtube.com/watch?v=hAk-7ImN6iM) — users, groups, roles & policies
- 📺 [Launch an EC2 instance](https://www.youtube.com/watch?v=5xc8M5WMM6s) — the full launch flow

**Reference**

- [instances.vantage.sh](https://instances.vantage.sh/) — EC2 instance pricing & specs lookup
- [AWS — What is IAM?](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
- [AWS — Amazon EC2](https://docs.aws.amazon.com/ec2/)
- [AWS CLI reference](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html)
- [AWS Free Tier](https://aws.amazon.com/free/)
