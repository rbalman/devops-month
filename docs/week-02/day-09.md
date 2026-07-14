# Day 2 · Networking II — DNS & Mail

> Yesterday you moved packets between *numbers*. But nobody types `142.250.x.x` into a browser — we use **names**. Today you learn the system that turns `example.com` into an address, how to interrogate it with `dig`, and how the same system quietly runs the world's **email** — which you'll prove by standing up a real mail server and routing it with your own DNS records.

## Learning Objectives

- Explain how a name resolves to an IP, step by step, from your machine outward
- Query DNS directly with `dig` and read the answer
- Recognize the common **record types** and what each is for
- Find where your machine's own resolver is configured (`/etc/hosts`, `resolv.conf`, `systemd-resolved`)
- Understand the DNS records that make **email** work — MX, SPF, DKIM, DMARC
- Stand up a **real mail server** (GreenMail in Docker) and send & receive email routed by your own DNS records

---

## Theory · ~20 min

### 1. DNS is a hierarchy

**DNS** (Domain Name System) maps human names to machine addresses. No single server holds every name — the namespace is a **tree**, and different servers own different branches:

```
                          . (root)
               ┌──────────┼───────────┐
             .com        .org        .np          ← top-level domains (TLDs)
               │                       │
           example                 fundevops       ← domains (you register one)
               │                       │
         ┌─────┴─────┐           ┌─────┴─────┐
        www        mail         www         mail   ← hosts/records in your zone
```

You read a name **right to left**, most-general first. Every name technically ends in a dot — the invisible **root**:

```
www.example.com.
│   │       │  └─ "." the root
│   │       └──── ".com" — the top-level domain (TLD)
│   └──────────── "example.com" — the domain you register & control
└──────────────── "www" — a host/record inside your zone
```

Whoever controls a level runs its **nameservers** and **delegates** the level below: root points to `.com`'s servers, `.com` points to `example.com`'s servers, and you run the records inside `example.com`.

### 2. How a name resolves — the flow

Your machine doesn't walk the tree itself. It hands the question to a **recursive resolver** (your ISP's, or a public one like `8.8.8.8`), which does the legwork and caches the answer:

```
Your app: "IP for www.example.com?"
   │
   ├─ 1. OS checks /etc/hosts (local override) and its cache
   ├─ 2. OS asks its recursive resolver (from /etc/resolv.conf)
   │
   │        the resolver walks the hierarchy (iterative queries):
   │        3. ROOT server       → "ask the .com servers"
   │        4. .COM server       → "ask example.com's nameservers"
   │        5. example.com's NS  → "www is 93.184.x.x"   ← authoritative answer
   │
   └─ 6. resolver caches it (for the TTL) and hands the IP back
```

Two terms worth knowing: your query *to* the resolver is **recursive** ("get me the final answer"); the resolver's queries *out* to root/TLD/authoritative servers are **iterative** ("just tell me who to ask next"). The **cache** in step 6 means the next lookup skips straight to the answer until the TTL expires.

!!! note "TTL — why DNS changes aren't instant"
    Every record carries a **TTL** (time-to-live) in seconds — how long resolvers may cache it. Change a record with a 3600s TTL and some of the world keeps seeing the old value for up to an hour. Before a migration, you *lower the TTL* in advance so the switch propagates fast.

### 3. The record types you'll meet

A DNS zone is a set of **records**. The ones that matter day-to-day:

| Record | Maps | Example / use |
|---|---|---|
| **A** | name → IPv4 | `example.com → 93.184.215.14` |
| **AAAA** | name → IPv6 | `example.com → 2606:2800:...` |
| **CNAME** | name → another **name** | `www → example.com` (an alias) |
| **MX** | domain → mail server(s) | where email for `@example.com` goes |
| **TXT** | name → free text | SPF, DKIM, domain verification |
| **NS** | domain → its nameservers | who is authoritative for the zone |
| **SOA** | — | the zone's "start of authority" metadata |
| **PTR** | IP → name | **reverse** DNS (used by mail servers) |

!!! tip "A record vs CNAME"
    An **A** record points at an *address*; a **CNAME** points at another *name* (which is then resolved). Use A for the apex (`example.com`), CNAME for subdomains that should follow another host (`www`, `app` → a load balancer's name).

### 4. Where *your* machine's DNS is configured

Three places decide how names resolve on your box:

- **`/etc/hosts`** — a static override, checked first. Great for local testing (point `myapp.local` at `127.0.0.1`).
- **`/etc/resolv.conf`** — lists the resolver(s) to ask. On Ubuntu 24.04 this is managed by **systemd-resolved** and usually points at the stub `127.0.0.53`.
- **`resolvectl`** — the tool to inspect what systemd-resolved is actually doing.

### 5. DNS also runs your email

Here's the part people miss: **email delivery is a DNS problem.** When a server wants to email `you@example.com`, it asks DNS for the domain's **MX** record to find the mail server. Three more DNS records decide whether that mail is *trusted* — this is how the internet fights spoofing:

| Record | Type | Answers the question |
|---|---|---|
| **MX** | MX | *Which server receives mail for this domain?* |
| **SPF** | TXT | *Which servers are allowed to send as this domain?* |
| **DKIM** | TXT | *Is this message cryptographically signed by the domain?* |
| **DMARC** | TXT | *What should happen to mail that fails SPF/DKIM?* |

Get these wrong and your mail silently lands in spam — or vanishes.

!!! danger "A test server is easy; production mail is brutal"
    In the lab you'll run **GreenMail**, a self-contained *test* mail server — perfect for seeing SMTP, IMAP, and DNS click together. But a *production* inbox is famously one of the hardest jobs in ops: your server's IP needs a clean reputation, correct **PTR** (reverse DNS), and perfect SPF/DKIM/DMARC, or the big providers silently drop your mail. That's why real projects reach for a managed sender (SES, Postmark) instead of self-hosting a mailbox.

---

## Lab · ~50 min

Work **inside your Vagrant VM**. Install the DNS tools:

```bash
sudo apt update && sudo apt install -y bind9-dnsutils
```

### Step 1 — Your first `dig`

```bash
dig example.com                 # the full response — read the ANSWER SECTION
dig +short example.com          # just the address
dig example.com A               # only A (IPv4) records
dig example.com AAAA            # only AAAA (IPv6)
```

In the full output, note the **ANSWER SECTION** and the number beside the record — that's the **TTL** counting down.

### Step 2 — Explore the record types

```bash
dig +short google.com MX        # mail servers (note the priority numbers)
dig +short google.com NS        # authoritative nameservers
dig +short google.com TXT       # text records — you'll see an SPF entry here
dig example.com SOA             # zone authority metadata
```

### Step 3 — Watch the hierarchy resolve

`+trace` walks the tree yourself — root → TLD → authoritative — instead of asking your cached resolver:

```bash
dig +trace www.wikipedia.org
```

Read it top to bottom: the **root** servers refer you to **`.org`**, which refers you to Wikipedia's nameservers, which give the final answer. That's steps 3–5 from the theory, made visible.

### Step 4 — Query a specific resolver, and reverse lookups

```bash
dig @1.1.1.1 example.com        # ask Cloudflare's resolver directly
dig @8.8.8.8 example.com        # ask Google's — compare the TTLs (caching!)

dig -x 8.8.8.8                  # reverse: IP → name (PTR record)
```

### Step 5 — Where your own machine resolves names

```bash
cat /etc/hosts                  # static overrides, checked first
cat /etc/resolv.conf            # note it points at 127.0.0.53 — the systemd-resolved stub
resolvectl status               # the real upstream resolvers your VM uses
```

Now prove `/etc/hosts` wins. Add a local override and test it:

```bash
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
dig +short myapp.local          # dig ignores /etc/hosts...
getent hosts myapp.local        # ...but the OS resolver (what apps use) honors it → 127.0.0.1
ping -c1 myapp.local            # resolves to localhost
```

!!! note "dig vs the OS resolver"
    `dig` talks straight to DNS servers, so it **skips** `/etc/hosts`. Real programs use the OS resolver (`getent`, `ping`, `curl`), which checks `/etc/hosts` first. That difference trips up everyone once — now it won't trip you.

Remove the test override when you're done:

```bash
sudo sed -i '/myapp.local/d' /etc/hosts
```

### Step 6 — Inspect the mail records of a real domain

```bash
dig +short google.com MX                    # who receives Google's mail
dig +short google.com TXT | grep spf        # SPF: allowed senders
dig +short _dmarc.google.com TXT            # DMARC policy
```

The DMARC record lives at the special `_dmarc.<domain>` name — read its `p=` value (`none`, `quarantine`, or `reject`): that's the domain's instruction for mail that fails authentication.

### Step 7 — Real-world demo: run a mail server, route it with DNS

This is where the theory pays off — run an actual mail server, point DNS at it (**A** + **MX**), then send a real email between two accounts and watch it travel the full path: **DNS → MX → SMTP → IMAP**.

!!! note "This demo runs on a public cloud VM, not Vagrant"
    Mail needs a public IP, a real domain, and open ports — a local VM can't offer those. Use a cloud VM with a public IP (you'll provision **EC2** properly in Week 4; here we just hand you the commands), and don't worry that **Docker** is only taught on Days 5–7 — copy-paste for now. Examples use `fundevops.com`; substitute your own domain.

**7.1 — Open the ports.** In the VM's firewall / security group, allow inbound TCP `22` (SSH), `3025` (SMTP), `3143` (IMAP), `8080` (GreenMail API).

**7.2 — Install Docker (Ubuntu 24.04):**

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER      # then log out and back in for this to take effect
docker --version
```

**7.3 — Run GreenMail** — a self-contained test server that speaks both SMTP and IMAP:

```bash
docker run -d --restart unless-stopped --name greenmail \
  -e GREENMAIL_OPTS="-Dgreenmail.setup.test.all -Dgreenmail.hostname=0.0.0.0 -Dgreenmail.auth.disabled -Dgreenmail.verbose" \
  -p 3025:3025 -p 3143:3143 -p 8080:8080 \
  greenmail/standalone:latest

docker logs greenmail | head       # confirm it started (note '-Dgreenmail.auth.disabled')
```

`3025` = SMTP (send), `3143` = IMAP (receive). `auth.disabled` auto-creates any mailbox on first login and sets **login = the full email address** — ideal for a demo, never for production.

**7.4 — Point DNS at it (the payoff).** In your domain's DNS, add two records — sections 1–3 made real:

| Type | Name | Value |
|---|---|---|
| **A** | `mail.fundevops.com` | `<EC2_PUBLIC_IP>` |
| **MX** | `fundevops.com` | `10 mail.fundevops.com` |

Verify they resolve, from anywhere:

```bash
dig +short mail.fundevops.com A     # → your server's IP   (the A record)
dig +short fundevops.com MX         # → 10 mail.fundevops.com   (the MX record)
```

The **A record** turns the name into your server's IP; the **MX record** is what a *real* sending server would look up to find where `@fundevops.com` mail goes. (GreenMail is self-contained, so Thunderbird connects to it directly by that hostname — which also proves your A record works.)

**7.5 — Add two accounts in Thunderbird** (File → New → Existing Mail Account → **Configure manually**). With `auth.disabled`, the **username is the full email**; the password can be anything.

| Setting | Sender | Receiver |
|---|---|---|
| Email / IMAP username | `sender@fundevops.com` | `receiver@fundevops.com` |
| Incoming (IMAP) | `mail.fundevops.com` : `3143` | same : `3143` |
| Outgoing (SMTP) | `mail.fundevops.com` : `3025` | same : `3025` |
| Connection security | None | None |
| IMAP auth | Normal password | Normal password |
| SMTP auth | No authentication (blank user) | No authentication (blank user) |

**7.6 — Send and receive.** Tail the server, then from `sender@` send a message to **`receiver@fundevops.com`** — the `To:` must match the receiver's IMAP username character-for-character:

```bash
docker logs -f greenmail
```

With verbose on you'll watch the SMTP `RCPT TO:<receiver@fundevops.com>` land; hit **Get Messages** on the receiver and the email appears. You just ran the whole path — **DNS (A/MX) → SMTP (3025) → IMAP (3143)** — the real-world scenario, end to end.

??? info "More detail — SMTP vs IMAP vs POP3 (and their secure ports)"
    Mail uses **two kinds** of protocol: one to **send** (SMTP) and one to **read** (IMAP or POP3). Each has a plaintext port and a TLS-encrypted one:

    | Protocol | Job | Plain / STARTTLS | Implicit TLS |
    |---|---|---|---|
    | **SMTP** (relay) | send server → server | 25 | — |
    | **SMTP** (submission) | send from a mail app → server | 587 | 465 |
    | **IMAP** | read mail kept **on the server** (multi-device sync) | 143 | 993 |
    | **POP3** | **download** mail to one device, then delete from server | 110 | 995 |

    - **IMAP vs POP3:** IMAP leaves mail on the server and syncs folders across every device (the modern default); POP3 pulls it to one machine and usually removes it from the server.
    - **STARTTLS vs implicit TLS:** *STARTTLS* opens plaintext on the normal port (25/587/143) then upgrades to encryption; *implicit TLS* (465/993/995) is encrypted from the first byte on a dedicated port. In production you expose only the encrypted variants.
    - **Why GreenMail used `3025`/`3143`:** it simply adds `3000` to the standard ports (`25→3025`, `143→3143`), so the container needs no root and sidesteps the commonly-blocked port 25.

!!! warning "Tear it down — it's an open relay"
    `auth.disabled` + public ports means anyone can use your server. This is a **demo only** — remove it and re-close the ports when done:
    ```bash
    docker rm -f greenmail
    ```

---

## Advanced Topics

- **Run your own resolver** — `dnsmasq` or `unbound` for local caching and split-horizon DNS → [Ubuntu — dnsmasq](https://help.ubuntu.com/community/Dnsmasq)
- **DNS over HTTPS/TLS** — encrypting the lookups themselves so the network can't snoop or tamper → [Cloudflare — DNS over HTTPS](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/)
- **The full email trust stack** — how SPF, DKIM, and DMARC actually validate a message → [Cloudflare — email security](https://www.cloudflare.com/learning/email-security/dmarc-dkim-spf/)
- **Registering & delegating a domain** — glue records, NS delegation, and how your `.com.np` becomes authoritative → [How DNS delegation works](https://www.cloudflare.com/learning/dns/glossary/what-is-dns/)
- **DNSSEC** — cryptographically signing a zone so resolvers can detect forged or cache-poisoned answers → [Cloudflare — how DNSSEC works](https://www.cloudflare.com/learning/dns/dnssec/how-dnssec-works/)
- **The apex-`CNAME` problem** — why you can't `CNAME` a root domain (`example.com`), and how providers fake it with ALIAS/ANAME/CNAME-flattening (you'll meet this pointing your domain at Go-Live) → [Cloudflare — CNAME flattening](https://www.cloudflare.com/learning/dns/glossary/dns-cname-flattening/)
- **DNS-based load balancing** — round-robin, weighted, and geo-routed records that spread traffic *before* it ever reaches Nginx (Day 4) → [Cloudflare — DNS load balancing](https://www.cloudflare.com/learning/performance/what-is-dns-load-balancing/)

---

## Assignment

1. **Map your own domain.** Use the domain *you* registered in Week 1 (Day 1). It already has authoritative nameservers, even before you add any records:
    ```bash
    dig NS <yourdomain>                   # your domain's nameservers (they exist today)
    dig <yourdomain> +trace | tail -15    # watch the hierarchy delegate down to them
    ```
    Then design the two records you'll create at **Go-Live** — a web **A** record and a mail **MX** — as a `Type | Name | Value | TTL` table, and add one line on why you'd set a *low* TTL right before launch.

2. **Run your own mail server — locally, in a few commands.** No domain or cloud needed: everything stays inside your Vagrant VM, using `test.local` as the domain.
    ```bash
    curl -fsSL https://get.docker.com | sudo sh     # Docker (previewed now; covered fully on Day 5)
    sudo docker run -d --name gm -p 3025:3025 -p 3143:3143 \
      -e GREENMAIL_OPTS="-Dgreenmail.setup.test.all -Dgreenmail.auth.disabled -Dgreenmail.verbose" \
      greenmail/standalone:latest
    sudo apt install -y swaks
    swaks --server localhost:3025 --from alice@test.local --to bob@test.local \
      --header "Subject: Hello" --body "My first self-hosted email"
    ```
    Find your `RCPT TO:<bob@test.local>` line in `sudo docker logs gm`, then send a **second** message to a *different* address (`carol@test.local`) and confirm GreenMail auto-created that mailbox too. Clean up with `sudo docker rm -f gm`. Deliverable: your two `swaks` commands and the two matching log lines.

---

## Further Reading

**Watch**

- [Everything You Need to Know About DNS — Crash Course: System Design #4](https://www.youtube.com/watch?v=27r4Bzuj5NQ) — a fast, visual tour of how DNS resolves
- [How DNS works — a friendly comic](https://howdns.works/) — the resolution walk, illustrated

**Reference**

- [Cloudflare Learning — What is DNS?](https://www.cloudflare.com/learning/dns/what-is-dns/) — records, resolvers, and caching explained
- [Cloudflare — SPF, DKIM & DMARC](https://www.cloudflare.com/learning/email-security/dmarc-dkim-spf/) — the email-trust records from §5

**Tools**

- [DNSViz](https://dnsviz.net/) — paste a domain and see its whole DNS/DNSSEC tree visualized
- [GreenMail](https://greenmail-mail-test.github.io/greenmail/) — the self-contained test mail server from the lab
- `man dig`, `man resolved.conf`, `man hosts`, `man nsswitch.conf` (the `hosts:` line that put `/etc/hosts` first in Step 5)
