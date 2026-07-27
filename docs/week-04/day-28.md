# Day 7 · Security Best Practices

> You built the end-to-end project fast and simple — SSH open to the world, no TLS, wide IAM, unscanned images. That's fine to *learn* on; it's not fine to *run*. The final discipline of DevOps is **DevSecOps**: security isn't a gate at the end, it's built into every layer you've already touched. Today you go back through the whole project — pipeline, cloud, network, secrets, images — and apply the best practices that turn a working demo into something you'd defend in production. Then we close the course.

!!! info "Security is a thread, not a day"
    You can't bolt security on at the end any more than you can bolt on testing. Today names the practices and applies the highest-impact ones to your project — but the real habit is doing this *as you build*, every day.

## Learning Objectives

- Map **security best practices** onto every layer you built this month
- Manage **secrets** properly and **scan** for leaked ones
- Apply **least privilege** to IAM roles and pipeline tokens
- Harden the **supply chain** — pin actions to SHAs, scan images & IaC, enable Dependabot
- **Lab:** harden the end-to-end project — network, pipeline scanning, and image hardening

---

## Prerequisites

- **Day 5 complete** — the end-to-end project (you'll harden it)
- Your `sample-app` repo with its workflows

---

## Theory · ~30 min

### 1. DevSecOps — shift left

The old model: build it, then a security team reviews it right before release (or after an incident). The problem — the later a flaw is found, the more it costs to fix. **Shifting left** means moving security *earlier*: into the pipeline, the code review, the pull request. A secret caught by a pre-commit scan costs nothing; the same secret leaked to a public repo is an emergency.

The mindset: **every layer you built has a security posture**, and most of it can be checked automatically in CI.

### 2. The security checklist — layer by layer

Each layer of your project, its top risk, and the practice that addresses it:

| Layer | Risk | Best practice |
|---|---|---|
| **Secrets** | Passwords/keys in git | Never commit; use GH secrets / Ansible Vault / SSM; **scan** for leaks |
| **IAM** | Over-broad cloud access | **Least privilege** — scope the OIDC role; no long-lived keys |
| **Network** | Open ports to the world | Tight security groups — SSH to your IP or via **SSM/bastion**, not `0.0.0.0/0` |
| **Transport** | Plaintext HTTP | **TLS everywhere** — HTTPS with a real certificate |
| **Images** | Vulnerable/bloated containers | Minimal pinned base, **non-root**, scan with Trivy |
| **Dependencies** | Known CVEs in libraries | **Dependabot** / `npm audit` — automated update PRs |
| **IaC** | Misconfigured infra (public bucket, open SG) | **Scan HCL** (Trivy config / Checkov) in CI |
| **Pipeline** | Compromised action, leaked token | **Pin actions to SHA**, least-privilege `GITHUB_TOKEN`, branch protection |

### 3. Secrets — the number-one rule

**Secrets never live in git.** You've done this right all week — GH Actions secrets, Ansible Vault, `TF_VAR` from the environment. Add one more layer: **scan** to make sure nothing slipped through. A tool like **Trivy** (or **gitleaks**) checks your code — and your git *history* — for anything that looks like a key. For values that live at runtime, graduate from Vault files to **AWS SSM Parameter Store** or **Secrets Manager**, which give you rotation and audit logs.

### 4. Least privilege — everywhere

Grant the *minimum* access needed, nowhere more:

- **IAM/OIDC** — the Day 3 role should allow only the services Terraform manages, and its trust policy should pin to your repo *and* branch (`...:ref:refs/heads/main`), not `:*`.
- **`GITHUB_TOKEN`** — set `permissions:` explicitly per workflow (`contents: read` by default; add `packages: write` only where you push). The default is broad; narrow it.
- **Database** — the app's DB user needs table access, not superuser.

### 5. Supply-chain security — trust, but pin

Your pipeline runs other people's code (every `uses:` is a third-party action). If one is compromised, it runs *in your pipeline with your secrets*.

!!! danger "This actually happened — the trivy-action compromise (March 2026)"
    In March 2026, attackers force-pushed **76 of 77 version tags** in `aquasecurity/trivy-action` to malicious commits. Anyone pinned to a *tag* like `@v0.28` silently pulled attacker code — with access to their pipeline secrets. Anyone pinned to a **full commit SHA** was unaffected, because a SHA can't be moved. This is *the* argument for pinning:

    ```yaml
    # ❌ mutable — a tag can be force-pushed to malicious code
    - uses: aquasecurity/trivy-action@v0.28

    # ✅ immutable — a commit SHA is content-addressed and can't change
    - uses: aquasecurity/trivy-action@<full-40-char-sha>   # v0.72.0
    ```

Pin third-party actions to SHAs, enable **Dependabot** (it opens PRs to bump those SHAs safely), and keep `GITHUB_TOKEN` permissions minimal so a rogue action can do little.

---

## Lab · ~45 min

Harden the end-to-end project. You won't rebuild it — you'll tighten what's already there.

### 1. Close the network

In `terraform/main.tf`, the SSH rule is wide open. Scope it to your IP:

```hcl
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["<YOUR_IP>/32"]     # was 0.0.0.0/0
  }
```

!!! tip "The runner tradeoff"
    Once SSH is locked to your IP, the **hosted-runner** deploy can't reach the box (dynamic IPs). The production answer is a **self-hosted runner in the VPC** or **AWS SSM** (no inbound SSH at all). For the lab, restrict to your IP and run Ansible from your laptop — and note SSM as the real fix.

Apply through a PR (GitOps!) and confirm SSH from elsewhere is refused.

### 2. Add security scanning to CI

**`.github/workflows/security.yml`** — scan images, IaC, and secrets on every PR, failing on serious findings. Pin the scanner to a SHA (per Section 5):

```yaml
name: Security

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - name: Scan IaC + secrets (filesystem)
        uses: aquasecurity/trivy-action@<full-sha>   # look up the current SHA for the latest release
        with:
          scan-type: fs
          scan-ref: .
          scanners: misconfig,secret        # misconfigured HCL + leaked secrets
          severity: HIGH,CRITICAL
          exit-code: "1"                     # fail the build on a finding

      - name: Scan the backend image
        uses: aquasecurity/trivy-action@<full-sha>
        with:
          scan-type: image
          image-ref: ghcr.io/${{ github.repository }}/api:latest
          severity: HIGH,CRITICAL
          exit-code: "1"
```

Open a PR and watch it scan. `trivy config` inherited all of tfsec's checks (tfsec was merged into Trivy in 2024), so this catches things like an open security group or a public bucket right in the PR.

!!! note "Trivy does three jobs"
    One tool covers **image** vulnerabilities, **IaC** misconfigurations (`misconfig`), and **secret** leaks — fewer moving parts than a separate tool for each. **Checkov** is a solid alternative for IaC scanning if you prefer.

### 3. Least-privilege the pipeline

Two quick, high-value changes:

- Add an explicit **`permissions:`** block to every workflow (default to `contents: read`, add only what each needs) — you can see it in the security workflow above.
- Turn on **branch protection** for `main` (repo → Settings → Branches): require a PR, require the CI + Security checks to pass, and disallow direct pushes. Now nothing reaches `main` unreviewed or unscanned.

### 4. Harden the backend image

Tighten `backend/Dockerfile` — pinned base, non-root, no dev deps:

```dockerfile
FROM node:24-alpine          # pinned, minimal base
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev        # production deps only
COPY . .
USER node                    # ← don't run as root
EXPOSE 3000
CMD ["node", "server.js"]
```

Re-scan (`trivy image`) and confirm fewer findings and a non-root user.

### 5. Automate dependency updates

**`.github/dependabot.yml`** — let Dependabot open PRs for outdated npm packages *and* GitHub Actions:

```yaml
version: 2
updates:
  - package-ecosystem: npm
    directory: /backend
    schedule: { interval: weekly }
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly }
```

Commit it, and Dependabot starts proposing safe, reviewable update PRs — including bumping your pinned action SHAs.

!!! success "You hardened it"
    Tighter network, scanned images and IaC, least-privilege pipeline, non-root containers, and automated updates — the same project, now defensible. This is what "shift left" looks like in practice.

---

## Course Wrap-Up

Look back at what you built in a month:

- **Week 1** — the Linux and shell fluency everything rests on.
- **Week 2** — networking, TLS, and containers: how services talk and ship.
- **Week 3** — Ansible, AWS, and Terraform: infrastructure and config as code.
- **Week 4** — CI/CD, an end-to-end project, GitOps, observability, and security: the whole delivery loop.

You can now take an app from source to a **monitored, secured, self-deploying system on AWS** — and explain every hop. That's a genuine entry-level DevOps skill set.

### What comes next

| Next | Why |
|---|---|
| **Kubernetes** | The dominant container orchestrator; unlocks Argo CD/Flux (real pull-based GitOps) |
| **A cloud cert** | AWS Solutions Architect Associate or the CNCF **KCNA** — validates the ground you covered |
| **Deeper observability** | Traces (Tempo/OpenTelemetry), SLOs, on-call practice |
| **Deeper security** | Vault, image signing (Sigstore/cosign), policy as code (OPA), the CIS benchmarks |
| **Managed containers** | ECS/Fargate or EKS — retire the hand-run EC2 |

### Job prep

- **Your portfolio is this repo.** The end-to-end project (Day 5) is your headline — a public repo with a clear README, an architecture diagram, and a runbook beats a list of buzzwords.
- **Rehearse the story.** Interviewers love "walk me through a project": trace a `git push` to a live, monitored, secured deploy. You built exactly that — practice telling it in 3 minutes.
- **Know the "why."** Not just *what* Terraform is, but *why* IaC over ClickOps; not just *what* CI/CD is, but *what pain* it removes. This course framed every tool that way — lean on it.

---

## Advanced Topics

- **Image signing** — sign and verify images with **cosign/Sigstore** so only trusted images deploy → [Sigstore](https://www.sigstore.dev/)
- **Policy as code** — enforce rules (no public S3, tags required) with **OPA/Conftest** in CI → [Open Policy Agent](https://www.openpolicyagent.org/)
- **Secrets at runtime** — **AWS Secrets Manager / SSM Parameter Store** with rotation, or **HashiCorp Vault** → [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- **CIS Benchmarks** — hardening standards for Linux, Docker, and Kubernetes → [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- **SAST/DAST** — CodeQL for code analysis, OWASP ZAP for running-app scans → [CodeQL](https://codeql.github.com/)

---

## Assignment — secure the capstone

Apply the hardening to your project and prove it.

**Part 1 — Green the scanners.** Get the **Security** workflow passing: run Trivy, then **fix** the HIGH/CRITICAL findings it reports (image CVEs, an over-open security group, any flagged secret). Submit the before (red, with findings) and after (green) runs.

**Part 2 — HTTPS the app.** Put the frontend behind **TLS** — either an ALB + ACM certificate (Week 3 pattern) or Let's Encrypt via a reverse proxy (e.g. Caddy/nginx + certbot) on the EC2. Confirm `https://<your-domain>` shows a valid padlock and HTTP redirects to HTTPS.

**Submit:** the hardened `terraform/` + `Dockerfile` + `security.yml` + `dependabot.yml`, the red→green scanner runs, a screenshot of branch protection enabled, and the browser padlock on your domain.

!!! danger "Final teardown"
    When your screenshots are captured, `terraform destroy` the project one last time and confirm in the console that **nothing is left running** — no EC2, no security groups you created, no idle resources. Congratulations on finishing the course. 🎉

---

## Further Reading

**Watch**

- 📺 [DevSecOps explained](https://youtu.be/nrhxNNH5lt0) — where security fits in the pipeline

**Reference**

- [Trivy — docs](https://trivy.dev/) · [`trivy config` (IaC)](https://trivy.dev/latest/docs/scanner/misconfiguration/) · [Checkov](https://www.checkov.io/)
- [GitHub — Security hardening for Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions) · [Pin actions to a full commit SHA](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
- [Dependabot](https://docs.github.com/en/code-security/dependabot) · [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS — IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) · [Docker — build security best practices](https://docs.docker.com/build/building/best-practices/)
