# monitoring-app — a two-host observability lab

A self-contained monitoring lab on AWS. **Terraform** provisions two EC2 hosts (with Docker
pre-installed); you then SSH in and bring the stack up by hand, so you see each piece work.

- **App host** — the thing being watched. Runs node-exporter (metrics), a random log
  generator (logs), and Alloy (ships logs to Loki).
- **Observability host** — the monitoring backend. Runs Prometheus, Loki, and Grafana.

## Layout

```
terraform/                  2 EC2 hosts + security group + Docker via user_data
app-instance/               runs on the APP host
  docker-compose.yml          node-exporter + random-logger + alloy
  alloy/config.alloy          tails container logs → remote Loki
observability-instance/     runs on the OBSERVABILITY host
  docker-compose.yml          prometheus + loki + grafana
  prometheus/prometheus.yml   scrapes the app host's node-exporter
  loki/loki-config.yml        single-binary Loki
```

## Signal flow

```
   App host                                Observability host
  node-exporter ─────────── scraped by ──▶ Prometheus ─┐
  random-logger ─▶ Alloy ──── pushes to ──▶ Loki ───────┼─▶ Grafana ─alert─▶ Discord
                                                        │      ▲
                                                        └──────┴── you (dashboards · Explore)
```

## Prerequisites

- An AWS account with credentials configured (`aws configure`) and Terraform installed
- An existing EC2 key pair
- A Discord server where you can create a webhook

---

## 1. Provision the two hosts

Clone the repo and move into the Terraform project:

```bash
git clone https://github.com/rbalman/devops-month.git
cd devops-month/examples/monitoring-app/terraform
```

Create your variables file, then edit it to set `key_name`:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Provision, then print the host IPs:

```bash
terraform init
terraform apply
terraform output
```

Wait about a minute for Docker to finish installing on both hosts.

---

## 2. App host — start the signals

SSH in and fetch the files:

```bash
ssh -i <your-key.pem> ubuntu@<app_public_ip>
git clone https://github.com/rbalman/devops-month.git
cd devops-month/examples/monitoring-app/app-instance
```

Point Alloy at the observability host's **private** IP:

```bash
sed -i "s/OBS_PRIVATE_IP/<observability_private_ip>/" alloy/config.alloy
```

Start node-exporter, the log generator, and Alloy:

```bash
docker compose up -d
docker compose ps
```

(Alloy will retry its push to Loki until you start Loki in step 3 — that's expected.)

---

## 3. Observability host — start the backend

In a second terminal, SSH into the observability host and fetch the files:

```bash
ssh -i <your-key.pem> ubuntu@<observability_public_ip>
git clone https://github.com/rbalman/devops-month.git
cd devops-month/examples/monitoring-app/observability-instance
```

Point Prometheus at the app host's **private** IP:

```bash
sed -i "s/APP_PRIVATE_IP/<app_private_ip>/" prometheus/prometheus.yml
```

Bring the services up one at a time:

```bash
docker compose up -d prometheus
docker compose up -d loki
docker compose up -d grafana
```

---

## 4. Grafana — wire it up (in the browser)

Open `http://<observability_public_ip>:3000` and log in with `admin` / `admin`.

**Add the data sources** — go to **Connections → Data sources → Add data source**:

- Prometheus → URL `http://prometheus:9090` → **Save & test**
- Loki → URL `http://loki:3100` → **Save & test**

**Import a dashboard** — go to **Dashboards → New → Import**, enter ID `1860`
(*Node Exporter Full*), and pick the Prometheus data source.

**Search logs** — go to **Explore**, pick **Loki**, and run:

```logql
{container="random-logger"}
```

---

## Tear down

Two EC2 instances bill by the hour. From your laptop:

```bash
cd devops-month/examples/monitoring-app/terraform
terraform destroy
```
