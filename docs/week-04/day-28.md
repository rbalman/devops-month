# Day 7 · Security Best Practices

> Everything you built this month, you built to *work* — and to work fast. A port left wide so you could reach the box. A role handed a little more access than it strictly needed. An image shipped without a second look. That's exactly how you should learn: get it running first. But "it runs" and "it's safe to run" are two different sentences, and the gap between them is where breaches live.

**DevSecOps** is the habit of closing that gap continuously — security woven into every layer as you build, not bolted on at the end. You can't bolt it on any more than you can bolt on testing. So today there's no new stack to build. Instead we walk back through everything you already made, one ring at a time, name the single highest-impact fix at each, and turn a working demo into something you'd be willing to defend in production.

## Learning Objectives

- Hold one durable mental model — the **4 C's** (Cloud · Cluster/Compute · Container · Code) — for *where* security lives
- Name the **top risk and best practice** at each layer of the project you built
- Apply the cross-cutting **principles** — least privilege, defense in depth, reduce attack surface, minimize blast radius, separation of duties — and treat **secrets** as a thread through every layer
- Understand **shift-left / DevSecOps** — why the **CI/CD pipeline** is where those practices get enforced

---

## Prerequisites

- The whole month — every layer you built (Linux host → network → containers → cloud → pipeline) is today's case study. There's no new lab; there's a new *lens*.

---

## Theory

### 1. The 4 C's of cloud-native security

Cloud-native security is usually drawn as **four nested layers** — the *4 C's*: **Cloud → Cluster → Container → Code**. They're concentric on purpose: **you can only secure a layer as well as the layer around it.** Great app code can't save you on a compromised host; a hardened host can't save you inside a wide-open cloud account. Security is *defense in depth* — each ring backs up the next.

An attacker meets your rings from the outside in: they can't touch your code until they're past your cloud, and can't reach the host until they're through the network. So that's how we'll walk them — Cloud first, Code last — the same path someone probing your system would take.

```
   ┌─────────────────────────────────────────────┐
   │ CLOUD — AWS account, IAM, VPC, security      │
   │  groups, TLS                                 │
   │   ┌───────────────────────────────────────┐  │
   │   │ CLUSTER / COMPUTE — the EC2 host,      │  │
   │   │  SSH/SSM access, Docker daemon         │  │
   │   │   ┌─────────────────────────────────┐  │  │
   │   │   │ CONTAINER — base image,         │  │  │
   │   │   │  non-root, scanned              │  │  │
   │   │   │   ┌───────────────────────────┐  │  │  │
   │   │   │   │ CODE — app + its deps,    │  │  │  │
   │   │   │   │  SAST, no CVEs            │  │  │  │
   │   │   │   └───────────────────────────┘  │  │  │
   │   │   └─────────────────────────────────┘  │  │
   │   └───────────────────────────────────────┘  │
   └─────────────────────────────────────────────┘
```

The 4 C's tell you *where*; a handful of **principles** tell you *how* — and they repeat at every layer. Watch for them in every section below:

- **Least privilege** — grant the *minimum* access needed, nowhere more (an IAM role, a DB user, a pipeline token).
- **Defense in depth** — no single control is trusted alone; each ring backs up the next.
- **Reduce the attack surface** — fewer open ports, smaller images, fewer dependencies, fewer privileges.
- **Minimize blast radius** — assume a breach *will* happen and contain it (network isolation, scoped credentials, short-lived tokens).
- **Separation of duties** — no single actor pushes straight to production; changes are reviewed and gated.

!!! tip "Secrets — the classic cross-cutting thread"
    The same secret appears at every C, and the rule shifts with the layer: **never in git** (Code) → **held by the pipeline** (CI/CD) → **delivered at runtime** from SSM / Secrets Manager (Cloud). "Manage your secrets" isn't one task; it's the same discipline applied at every layer.

| Layer | Top risk | Best practice |
|---|---|---|
| **☁️ Cloud** | Over-broad access, open ports, plaintext | Least-privilege **IAM/OIDC**, tight **security groups**, **TLS everywhere** |
| **🖥️ Cluster / Compute** | Exposed host, open management plane | SSH via **SSM** or your IP (not `0.0.0.0/0`), no long-lived keys, patch the host |
| **📦 Container** | Vulnerable/bloated images | Minimal pinned base, **non-root**, scan with Trivy |
| **📝 Code** | CVEs in deps, secrets or misconfig in source | **Dependabot** / `npm audit`, **SAST**, secret & **IaC scanning** |

And wrapping all four: the **CI/CD pipeline** (Section 6) — where every one of these checks gets *enforced automatically*, before code ever reaches production.

### 2. Cloud — the account & network

Your AWS account is the ring an attacker reaches first — no code, no host, just the internet and your front door. Get it wrong and the layers inside don't matter. Four choices carry most of the weight:

- **Identity — least privilege.** A stolen credential skips every other defense at once. The OIDC role your pipeline assumes should touch only the services it manages, and its trust policy should pin your repo *and* branch (`...:ref:refs/heads/main`, never `:*`). **No long-lived access keys** — OIDC hands out short-lived credentials that expire on their own.
- **Network — tight security groups.** SSH open to `0.0.0.0/0` and bots are trying passwords within minutes. Scope SSH to your IP, or close the port entirely and use **SSM Session Manager**. Only the load balancer should face the world.
- **Transport — TLS everywhere.** HTTP in the clear leaks every value in the request. Terminate **HTTPS with a real certificate** (ACM on the ALB) and redirect HTTP → HTTPS.
- **Runtime secrets — not in the image.** Keep them in **SSM Parameter Store** or **Secrets Manager** (rotatable, audited), never a `.env` baked into the build.
- **Watch the account.** **CloudTrail** logs every API call and **GuardDuty** flags the suspicious ones — your audit trail for *what happened*.

*Not fixed here:* a public S3 bucket or open security group is a real cloud risk, but it's really a **typo in your Terraform** — so you catch it in the Code ring (Section 5), long before it ships. Cloud is the consequence; Code is where you stop it.

### 3. Compute — the host

A foothold got through anyway — now they're on the box: a Linux **EC2 instance** (or any VM) running your containers. This ring is about making that foothold as small and as boring as possible:

- **Close the SSH port to the world.** An inbound rule allowing port 22 from `0.0.0.0/0` lets the whole internet knock. Restrict the source to a single admin IP (`x.x.x.x/32`), or remove inbound SSH entirely and reach the host through a session/bastion service that needs no open port. On the host, disable password login (`PasswordAuthentication no`) — key auth only.
- **Give the instance a least-privilege role.** A VM's attached identity (its **IAM instance profile**) is what any process on it can act as in the cloud. Scope that role to exactly what the app needs — pull its container image, read its own secrets — and nothing more. An over-broad role turns one compromised process into a compromised account.
- **Patch the box.** A machine image ages the moment it boots. Keep the OS and the container engine current — a host is only as safe as its last update — and automate the security patches so it doesn't depend on someone remembering.
- **Don't run as root.** Run the application as an unprivileged user, not `root` on the host — so a process that gets exploited can't own the whole machine.
- **Isolate the database tier.** The database should never be publicly routable. Keep it on a private network where only the application tier can reach it, with a firewall/security group that permits traffic *from the app and from nowhere else* — never a public IP, never the open internet.

!!! note "Why this ring is called *Cluster* elsewhere"
    The classic model names this ring **Cluster** because it assumes Kubernetes, where it becomes a whole discipline — RBAC, workload identity, network policies, Pod Security Standards, admission control (Kyverno/OPA), runtime detection (Falco). Same instinct — lock the control plane, least privilege, isolate workloads — over a much bigger surface. On our single EC2 host it's just *compute*, right-sized to the stack. See [where to go next](#where-to-go-next).

### 4. Container — the image

Every image you ship is a small operating system, and most of it is code you didn't write. Shrink what an attacker inherits if they get inside one:

- **Minimal, pinned base.** `node:24-alpine` (or **distroless**) over `node:latest` — smaller attack surface, reproducible build. A pinned digest means you know *exactly* what's running.
- **Multi-stage build, prod deps only.** `npm ci --omit=dev` so build tooling never rides along into production — fewer packages, fewer CVEs.
- **Don't run as root.** One `USER node` line turns a container breakout into a nobody instead of a handover — the highest value-per-character change in this whole day.
- **Scan and gate.** **Trivy** flags known CVEs in your base and packages; fail the build on HIGH/CRITICAL so a vulnerable image never ships. The 2026 baseline: **block unsigned or unscanned images** entirely (sign with **cosign**, verify at pull).

!!! example "A hardened backend image"
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

### 5. Code — the app & its dependencies

The innermost ring is everything in your repo — the app you wrote, the dependencies you *didn't* (most of your real attack surface is other people's code), and **your Terraform too** (infrastructure-as-code is code, so it's secured like code). Four scans cover it, all cheap because they run in the pull request:

- **Secrets — never in git.** Not in source, not in history. **gitleaks** or Trivy (`scanners: secret`) checks both. A key in a public repo is an emergency; caught pre-commit it costs nothing.
- **IaC misconfig.** That public S3 bucket from Section 2 is a typo in HCL — **Trivy config** (`scanners: misconfig`) or **Checkov** catches it in the PR, long before `apply`.
- **Dependencies (CVEs).** Commit your lock files and let **Dependabot** (or `npm audit`) open the bump PRs for you. Turn it on, keep it green.
- **Your own code — SAST.** **CodeQL** flags injection and unsafe patterns right where you're already reviewing.
- **Know the classics.** The [**OWASP Top 10**](https://owasp.org/www-project-top-ten/) is the short list of what actually gets apps breached — read it once and remember it.

Source, dependencies, *and* IaC — all scanned in the PR. That's the heart of **shift left**. The machine that runs those scans on every change is the next section.

### 6. CI/CD & shift left — the pipeline that enforces it all

Here's the DevSecOps punchline. Every practice in Sections 2–5 is only a *good intention* until something checks it automatically. That something is your **pipeline**.

**Shift left** means moving each check *earlier* — the cost of a flaw grows the further right it's caught, so push it as far left as it'll go. A leaked key caught by a pre-commit hook costs nothing; the same key in a public repo is an emergency. Concretely, that's three lines of defense, left to right:

- **Pre-commit — catch it before it's even committed.** Run [`pre-commit`](https://pre-commit.com/) hooks locally: **gitleaks** for secrets, a linter/formatter (`terraform fmt`, `eslint`), and `hadolint` for the Dockerfile. One hour to set up, and bad commits never leave the laptop.
- **On every pull request — scan and gate.** The PR is your main checkpoint. Run the full sweep and **fail the build** on serious findings so nothing insecure merges:
    - **Secrets** — `gitleaks` / Trivy over the code *and history*.
    - **SAST** — **CodeQL** (or SonarQube) on your source for injection, unsafe patterns.
    - **Dependencies (SCA)** — `npm audit` / Trivy on your lock files for known CVEs.
    - **IaC** — `trivy config` / Checkov on the Terraform for misconfigs.
    - **Image** — `trivy image` on the built container for base-layer CVEs.
- **On merge / pre-deploy — last gate.** Re-scan the release image, verify its **signature** (cosign), and only then deploy. Nothing unsigned or unscanned reaches production.

!!! tip "Fast feedback or developers route around it"
    A gate that takes 20 minutes or drowns people in false positives gets disabled. Keep scans fast, **fail only on HIGH/CRITICAL**, cache aggressively, and put the result *in the PR* where the author already is. Security that slows delivery loses; done right, it speeds it up.

But the pipeline runs *other people's code*, too — every `uses:` is a third-party action running with your secrets. So the pipeline itself needs hardening:

- **Pin actions to a full commit SHA**, not a tag.
- **Least-privilege `GITHUB_TOKEN`** — set `permissions:` explicitly per workflow (`contents: read` by default; add only what each job needs).
- **Branch protection on `main`** — require a PR, require the security checks to pass, disallow direct pushes. Now nothing reaches production unreviewed or unscanned.

!!! danger "This actually happened — the trivy-action compromise (March 2026)"
    Attackers force-pushed **76 of 77 version tags** in `aquasecurity/trivy-action` to malicious commits. Anyone pinned to a *tag* like `@v0.28` silently pulled attacker code — with access to their pipeline secrets. Anyone pinned to a **full commit SHA** was unaffected, because a SHA can't be moved. This is *the* argument for pinning:

    ```yaml
    # ❌ mutable — a tag can be force-pushed to malicious code
    - uses: aquasecurity/trivy-action@v0.28

    # ✅ immutable — a commit SHA is content-addressed and can't change
    - uses: aquasecurity/trivy-action@<full-40-char-sha>   # v0.72.0
    ```

    Pin third-party actions to SHAs, let **Dependabot** open PRs to bump them safely, and keep `GITHUB_TOKEN` minimal so a rogue action can do little.

!!! note "Shift left *and* watch right"
    Scanning stops at deploy; it can't see an attack on the *running* system. That's the job of the observability stack from [Day 6](day-27.md), together with the account-level **CloudTrail / GuardDuty** from the Cloud layer. Shift left to prevent, watch right to detect.

---

## Where to go next

You can now take an app from source to a **monitored, secured, self-deploying system on AWS** — and explain every hop. That's a genuine entry-level DevOps skill set, and the exact foundation the whole cloud-native world builds on.

*(Housekeeping: if the capstone is still running, `terraform destroy` it and confirm the console is empty — no EC2, no idle resources quietly billing you.)*

Each of these is a **broad next chapter**, not a single tool — pick the one that pulls you and go deep:

| Direction | What it is — and why it's the natural next step |
|---|---|
| **Kubernetes** | The dominant container orchestrator. It turns the "Compute" ring into a real "Cluster" and unlocks the entire cloud-native ecosystem below — the single highest-leverage thing to learn after this course. |
| **GitOps** | Git as the one source of truth: tools like **Argo CD** and **Flux** run *inside* the cluster and continuously reconcile it to what's declared in the repo. The pull-based successor to the push pipeline you built this month. |
| **Platform engineering** | Package everything you learned — IaC, pipelines, clusters — into a self-service internal platform so product teams ship without reinventing it each time. Where much of the industry is heading. |
| **SRE & deeper observability** | Running systems *reliably*, not just shipping them: traces (OpenTelemetry), SLOs and error budgets, on-call and incident response. |
| **Cloud-native security** | Today's lens taken to production depth — secrets management (Vault), image signing (cosign/Sigstore), policy-as-code (OPA/Kyverno), the CIS benchmarks. |
| **A cloud certification** | AWS Solutions Architect Associate or the CNCF **KCNA** / **CKA** — validates the ground you covered and clears résumé filters. |

---

## Advanced Topics

- **Image signing** — sign and verify images with **cosign/Sigstore** so only trusted images deploy → [Sigstore](https://www.sigstore.dev/)
- **Policy as code** — enforce rules (no public S3, tags required) with **OPA/Conftest** in CI → [Open Policy Agent](https://www.openpolicyagent.org/)
- **Secrets at runtime** — **AWS Secrets Manager / SSM Parameter Store** with rotation, or **HashiCorp Vault** → [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- **CIS Benchmarks** — hardening standards for Linux, Docker, and Kubernetes → [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- **SAST/DAST** — CodeQL for code analysis, OWASP ZAP for running-app scans → [CodeQL](https://codeql.github.com/)

---

## Assignment — Find the job 🎯

Your final assignment isn't in a terminal: take everything you've built this month, and go find the job you want. Best of luck — you've earned the shot. 🚀

---

## Further Reading

**Watch**

- 📺 [DevSecOps explained](https://youtu.be/nrhxNNH5lt0) — where security fits in the pipeline

**Reference**

- [The 4C's of Cloud Native Security](https://notes.kodekloud.com/docs/Kubernetes-and-Cloud-Native-Security-Associate-KCSA/Overview-of-Cloud-Native-Security/The-4Cs-of-Cloud-Native-Security/page) — the model this day is built on
- [Trivy — docs](https://trivy.dev/) · [`trivy config` (IaC)](https://trivy.dev/latest/docs/scanner/misconfiguration/) · [Checkov](https://www.checkov.io/)
- [GitHub — Security hardening for Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions) · [Pin actions to a full commit SHA](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
- [`pre-commit` framework](https://pre-commit.com/) · [gitleaks](https://github.com/gitleaks/gitleaks) — shift the first scan all the way to the laptop
- [Dependabot](https://docs.github.com/en/code-security/dependabot) · [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS — IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) · [Docker — build security best practices](https://docs.docker.com/build/building/best-practices/)
