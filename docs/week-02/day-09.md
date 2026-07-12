# Day 09 · Networking II — DNS & Mail

> Yesterday you moved packets between *numbers*. But nobody types `142.250.x.x` into a browser — we use **names**. Today you learn the system that turns `example.com` into an address, how to interrogate it with `dig`, and how the same system quietly runs the world's **email**. You'll even speak the mail protocol by hand.

## Learning Objectives

- Explain how a name resolves to an IP, step by step, from your machine outward
- Query DNS directly with `dig` and read the answer
- Recognize the common **record types** and what each is for
- Find where your machine's own resolver is configured (`/etc/hosts`, `resolv.conf`, `systemd-resolved`)
- Understand the DNS records that make **email** work — MX, SPF, DKIM, DMARC
- Watch an SMTP conversation and understand why self-hosting mail is hard

---

## Theory · ~20 min

### 1. DNS is the internet's phone book

**DNS** (Domain Name System) maps human names to machine addresses. When you ask for `example.com`, the answer isn't stored in one place — it's found by walking a **hierarchy**, right to left:

```
              www.example.com.
                            └─ "." the root
                     └──────── ".com"  Top-Level Domain (TLD)
             └──────────────── "example.com"  the domain (its owner runs the nameservers)
         └──────────────────── "www"  a host/record inside that domain
```

### 2. How a lookup actually resolves

Your machine rarely knows the answer — it asks a **resolver**, which walks the hierarchy for you and caches the result:

```
Your app asks: "IP for www.example.com?"
  1. OS checks /etc/hosts           (a local override file)
  2. OS asks its configured resolver (e.g. systemd-resolved → 8.8.8.8)
  3. Resolver asks a ROOT server     → "ask the .com servers"
  4. Resolver asks a .COM server     → "ask example.com's nameservers"
  5. Resolver asks example.com's NS  → "it's 93.184.x.x"
  6. Resolver caches it (for the record's TTL) and answers your app
```

That whole trip happens in milliseconds, and the **cache** means step 3–5 are skipped next time.

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

!!! danger "Why we don't self-host a real mailbox in this course"
    Standing up production email (Postfix + Dovecot) is famously one of the hardest jobs in ops: your server's IP needs a clean reputation, correct **PTR** (reverse DNS), and perfect SPF/DKIM/DMARC, or the big providers drop your mail on the floor. It's a rabbit hole that would eat the whole week. Today we learn the **DNS + protocol layer** — which is what you actually configure — and leave running a mailbox to specialists (or a managed provider like SES/Postmark).

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

### Step 6 — Inspect the mail records of a real domain

```bash
dig +short google.com MX                    # who receives Google's mail
dig +short google.com TXT | grep spf        # SPF: allowed senders
dig +short _dmarc.google.com TXT            # DMARC policy
```

The DMARC record lives at the special `_dmarc.<domain>` name — read its `p=` value (`none`, `quarantine`, or `reject`): that's the domain's instruction for mail that fails authentication.

### Step 7 — Speak SMTP by hand (the mail protocol is just text)

Just like HTTP yesterday, SMTP is a plaintext conversation — so we poke at it with the same `nc`. First find a mail server, then talk to it:

```bash
dig +short gmail.com MX          # pick the hostname with the lowest priority number
nc <that-mail-server> 25         # e.g. nc gmail-smtp-in.l.google.com 25
```

If it connects, type the opening of an SMTP conversation and watch the server reply to each line:

```
HELO devops-month.local
MAIL FROM:<you@example.com>
RCPT TO:<someone@gmail.com>
```

Each command gets a numeric reply (`250 OK`, etc.). Type `QUIT` to end. **This is exactly what every mail server does** — you're just doing it by hand.

!!! warning "Port 25 is often blocked"
    Many home ISPs and cloud providers block **outbound port 25** to fight spam, so the `nc ... 25` may hang or refuse. That's not a bug in your setup — it's the same reason self-hosting mail is hard. If it's blocked, you've still learned the conversation; move on.

Clean up the test override from Step 5 when you're done:

```bash
sudo sed -i '/myapp.local/d' /etc/hosts
```

---

## Advanced Topics

- **Run your own resolver** — `dnsmasq` or `unbound` for local caching and split-horizon DNS → [Ubuntu — dnsmasq](https://help.ubuntu.com/community/Dnsmasq)
- **DNS over HTTPS/TLS** — encrypting the lookups themselves so the network can't snoop or tamper → [Cloudflare — DNS over HTTPS](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/)
- **The full email trust stack** — how SPF, DKIM, and DMARC actually validate a message → [Cloudflare — email security](https://www.cloudflare.com/learning/email-security/dmarc-dkim-spf/)
- **Registering & delegating a domain** — glue records, NS delegation, and how your `.com.np` becomes authoritative → [How DNS delegation works](https://www.cloudflare.com/learning/dns/glossary/what-is-dns/)

---

## Assignment

1. **Investigate a domain end-to-end.** Choose a domain you use daily. With `dig`, gather: its A record and TTL, its nameservers (NS), its mail servers (MX with priorities), and its DMARC policy (`_dmarc.<domain>` TXT). Present it as a short table, and in two sentences explain what the DMARC `p=` value means for someone trying to spoof that domain.

2. **Prepare your Go-Live domain.** You registered a `.com.np` domain on Day 01. Run `dig NS <yourdomain>.com.np` and `dig <yourdomain>.com.np` and record what exists today. Then write down the **exact A record** you *will* create in Week 4 to point it at your public server — name, type, value (use a placeholder IP like `203.0.113.10`), and a TTL, with one line explaining why you'd pick a *low* TTL right before going live.

---

## Further Reading

- [How DNS works — a friendly comic](https://howdns.works/) — the resolution walk, illustrated
- [Cloudflare Learning — What is DNS?](https://www.cloudflare.com/learning/dns/what-is-dns/)
- [DNSViz](https://dnsviz.net/) — paste a domain and see its whole DNS/DNSSEC tree visualized
- `man dig`, `man resolved.conf`, `man hosts`
