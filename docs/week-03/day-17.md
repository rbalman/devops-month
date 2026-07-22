# Day 3 · AWS I — Cloud Foundations & the Console

> For two weeks you've run everything on machines you can touch — Vagrant boxes, Docker containers on your laptop. Today **Operation: Go Live moves to the cloud**. Before we launch anything, you need the map: what "the cloud" actually means (**IaaS / PaaS / SaaS**), who the big providers are, and how to find your way around the **AWS Management Console**. This is the one light-on-hands day of the AWS block — tomorrow you launch a real server. Today you get oriented (and set a billing alarm so the cloud never surprises you).

!!! warning "Turn on billing alerts before anything else"
    The cloud bills by the hour (or the request). Nothing today costs money, but **do the account + billing-alarm step in the lab first** — it's the seatbelt for the rest of the week.

## Learning Objectives

- Explain the three cloud service models — **IaaS, PaaS, SaaS** — and place real products in each
- Name the **major cloud providers** and roughly where AWS sits in the market
- Describe AWS **regions** and **availability zones** and why they exist
- Navigate the **AWS Management Console**: region selector, service search, account menu, CloudShell
- Create an AWS account and set a **billing alarm**

---

## Prerequisites

- A credit/debit card (AWS requires one to open an account; the free tier covers this week)
- An email address you control

---

## Theory · ~25 min

### 1. What "the cloud" is — and the three service models

"The cloud" just means **renting computing resources over the internet** instead of buying and racking your own hardware. Someone else owns the data center, the power, the cooling, the network — you pay for what you use and walk away when you're done.

How *much* they manage vs. how much you manage is the whole story. That's the **IaaS / PaaS / SaaS** spectrum:

| Model | You manage | Provider manages | Real example |
|---|---|---|---|
| **IaaS** — Infrastructure as a Service | OS, runtime, app, data | Servers, storage, network, virtualization | **AWS EC2**, Google Compute Engine |
| **PaaS** — Platform as a Service | Just your app + data | Everything below the app (OS, runtime, scaling) | **Heroku**, AWS Elastic Beanstalk, Vercel |
| **SaaS** — Software as a Service | Nothing — you just use it | The entire stack | **Gmail**, Slack, Salesforce |

A useful analogy: **IaaS is renting a plot of land and building the house yourself; PaaS is renting a furnished apartment; SaaS is staying in a hotel.** This week lives almost entirely in **IaaS** (EC2, VPC, load balancers) — the layer where DevOps engineers do most of their work — with a few managed (PaaS-ish) services sprinkled in.

### 2. The major cloud providers

| Provider | Notes |
|---|---|
| **AWS** (Amazon Web Services) | The market leader (~30% share); widest service catalog; what this course uses |
| **Microsoft Azure** | Strong in enterprise / Microsoft shops (~20–25%) |
| **Google Cloud (GCP)** | Strong in data, ML, Kubernetes (~10–12%) |
| **Others** | DigitalOcean & Linode (developer-friendly, simpler), Oracle Cloud, IBM, Alibaba Cloud |

The concepts transfer: a "VM" is EC2 on AWS, a "Compute Engine instance" on GCP, a "Virtual Machine" on Azure. Learn one deeply and the others become a translation exercise.

### 3. AWS Introduction

#### A brief history

AWS launched in **2006** with S3 and EC2 — Amazon rented out the spare capacity it had built for its own retail platform, and effectively invented the modern cloud market. It's been the **#1 provider** ever since and is Amazon's most profitable division. Today it offers **200+ services** — browse the whole catalog on the visual [**AWS periodic table**](https://awsperiodictable.com) — you'll touch about a dozen of the foundational ones this week.

#### Regions and availability zones

AWS is physically spread across the globe:

- A **Region** is a geographic area — `us-east-1` (N. Virginia), `eu-west-1` (Ireland), `ap-south-1` (Mumbai). You pick one close to your users. Most resources are **region-scoped**: an instance in `us-east-1` is invisible from the `eu-west-1` console.
- An **Availability Zone (AZ)** is one or more isolated data centers *within* a region — `us-east-1a`, `us-east-1b`. Spreading resources across AZs is how you survive a single data-center failure (you'll do exactly this with a load balancer on Day 5).

See the full, current list of regions and their AZs on AWS's own map: [**AWS Global Infrastructure — Regions & Availability Zones**](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/).

!!! tip "📺 Watch — AWS Regions & Availability Zones"
    A short, clear explainer of the region/AZ model you just read.

    [![AWS Regions & Availability Zones](https://img.youtube.com/vi/3XFODda6YXo/hqdefault.jpg){ width="360" }](https://www.youtube.com/watch?v=3XFODda6YXo)

### 4. Accessing AWS Resources

There are three ways to work with AWS — the same actions, three interfaces. You'll use all of them this week.

#### 4.a The Management Console

The **Console** (`console.aws.amazon.com`) is the web UI for AWS — where you'll learn by clicking before you automate. The four things to find immediately:

- **Region selector** (top-right) — *always check this first;* resources you create only exist in the selected region.
- **Service search** (top bar) — type `EC2`, `IAM`, `S3` to jump anywhere.
- **Account menu** (top-right) — billing, security credentials, sign-out.
- **CloudShell** (terminal icon) — a browser terminal with the AWS CLI pre-authenticated, so you can run `aws ...` commands without installing anything.

!!! tip "📺 Watch — AWS Management Console tour"
    A quick navigation walkthrough of the console you're about to open.

    [![AWS Management Console tour](https://img.youtube.com/vi/i331jNgsL_4/hqdefault.jpg){ width="360" }](https://www.youtube.com/watch?v=i331jNgsL_4)

#### 4.b The AWS CLI

The console is great for learning; the **CLI** is how you do real work — scriptable, repeatable, and what tools like Ansible and Terraform drive under the hood. Install it on **Ubuntu 24.04**:

```bash
sudo apt update && sudo apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version          # confirm: aws-cli/2.x.x ...
```

Then authenticate it with an IAM user's **access key** (you'll create that user tomorrow):

```bash
aws configure          # paste Access Key ID + Secret, set default region + output=json
aws sts get-caller-identity    # confirm who you are
```

> Full, always-current install steps for every OS: [AWS CLI — Install or update](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

#### 4.c The AWS API

Under the hood, both the console and the CLI just make **HTTPS API calls** to AWS. Every SDK and tool speaks this same API — that's why anything you can click, you can automate. The CLI command `aws ec2 describe-instances` is really a plain HTTPS request to the EC2 endpoint — visible as raw `curl`:

```bash
curl "https://ec2.us-east-1.amazonaws.com/?Action=DescribeInstances&Version=2016-11-15" \
  -H "X-Amz-Date: 20260722T120000Z" \
  -H "Authorization: AWS4-HMAC-SHA256 \
      Credential=AKIAEXAMPLE/20260722/us-east-1/ec2/aws4_request, \
      SignedHeaders=host;x-amz-date, \
      Signature=<sigv4-signature>"
```

It's just HTTP + query parameters. The one hard part is that `Authorization` header — a **SigV4 signature** derived from your secret key that AWS uses to authenticate the request. Computing it by hand is painful, which is exactly why the CLI and SDKs exist: they build and sign this request for you.

Same action, three doors: **click it** (Console), **script it** (CLI), or **call it** (raw API/SDK).

---

## Lab · ~35 min

Today's lab is *setup and orientation* — no paid resources, so no teardown.

### Step 1 — Create your AWS account

1. Go to [aws.amazon.com](https://aws.amazon.com) → **Create an AWS Account**.
2. Enter email, account name, and a card (required; free tier covers this week).
3. Choose the **Basic (free) support plan**.
4. Sign in to the **Console** as the **root user**.

### Step 2 — Set a billing alarm (do this now)

1. In the console, search **Billing and Cost Management**.
2. **Budgets → Create budget → Zero spend / monthly cost budget**, set a **$1** threshold.
3. Enter your email for the alert. You'll now get an email the moment anything starts costing money.

!!! danger "Protect the root user"
    The **root** account can do *anything* and can't be restricted. Enable **MFA** on it (Account menu → Security credentials → MFA), then stop using it for daily work — tomorrow you'll create an IAM user for that.

### Step 3 — Tour the console

- Open the **Region selector** (top-right) and switch between two regions — notice the URL and available resources change.
- Set your working region (e.g. **`us-east-1`** or the one nearest you) and keep it consistent all week.
- Use the **service search** to open **EC2**, then **IAM**, then **S3** — just to see where they live.

### Step 4 — Open CloudShell and confirm identity

Click the **CloudShell** icon (terminal, top bar) and run:

```bash
aws sts get-caller-identity     # prints your account ID and current identity
aws ec2 describe-regions --query 'Regions[].RegionName' --output text
```

The first confirms the CLI is authenticated as you; the second lists every region available to your account. You now have both the GUI and the CLI at your fingertips.

### Step 5 — Install and configure the AWS CLI on your machine

CloudShell is handy, but real work happens from the CLI on your own laptop. This video walks the whole step end to end — installing the CLI, creating an access key ID & secret access key, and running `aws configure`:

!!! tip "📺 Watch — Install the CLI, create keys & run `aws configure`"
    Full walkthrough of installing the AWS CLI, generating your access key, and configuring it.

    [![Install & configure the AWS CLI](https://img.youtube.com/vi/OG-hrdX2CdU/hqdefault.jpg){ width="360" }](https://www.youtube.com/watch?v=OG-hrdX2CdU)

Install it (Ubuntu 24.04 — full steps in §4.b):

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version
```

Configure it. You'll create a dedicated IAM user for this **tomorrow**, so for today make a **temporary access key** and delete it at the end of this step (Account menu → **Security credentials → Create access key**). *(Prefer not to create a key yet? Skip `aws configure` and run the commands below in CloudShell, where you're already authenticated.)*

```bash
aws configure          # paste the Access Key ID + Secret, region e.g. us-east-1, output json
```

Now run a few read-only commands to feel the CLI:

```bash
aws sts get-caller-identity                                    # who am I / which account
aws ec2 describe-regions --output table                        # every region you can use
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].InstanceId' --output text   # none yet — expect empty
aws ec2 describe-vpcs \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Default:IsDefault}' --output table   # your default VPC
```

If you created a temporary access key above, **delete it now** (same Security credentials page) — you'll switch to a proper IAM user tomorrow.

---

## Advanced Topics

*Optional, adjacent to today — each links straight to the source:*

- [AWS Organizations](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html) — manage many accounts (prod / dev / sandbox) under one billing umbrella with guardrails.
- [Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model/) — the exact line between what AWS secures and what you secure.
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) — the six pillars of a sound cloud architecture.
- [Cost Explorer](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html) — visualize and forecast spend by service and tag.

---

## Further Reading

**Watch**

- 📺 [AWS Regions & Availability Zones](https://www.youtube.com/watch?v=3XFODda6YXo) — the region/AZ model
- 📺 [AWS Management Console tour](https://www.youtube.com/watch?v=i331jNgsL_4) — console navigation

**Reference**

- [AWS — Global Infrastructure: Regions & Availability Zones](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/)
- [AWS periodic table](https://awsperiodictable.com) — every AWS service, visual catalog
- [AWS — What is cloud computing?](https://aws.amazon.com/what-is-cloud-computing/)
- [AWS Free Tier](https://aws.amazon.com/free/) — know what's covered before you click
- [AWS — Types of cloud computing (IaaS/PaaS/SaaS)](https://aws.amazon.com/types-of-cloud-computing/)
- [AWS Documentation](https://docs.aws.amazon.com) — the official docs for every service
