# Day 09 · Networking II — SSH, DNS & TLS

## Learning Objectives

- Use SSH to connect to remote servers and manage keys
- Understand how DNS resolves names to IPs
- Know what TLS does and how to inspect certificates

---

## Theory · ~20 min

### SSH — Secure Shell

SSH lets you securely log into a remote machine over an encrypted connection. It replaced Telnet, which sent everything in plaintext.

**Key-based authentication** is the standard. Instead of a password, you generate a key pair:

- **Private key** (`~/.ssh/id_ed25519`) — stays on your machine, never shared
- **Public key** (`~/.ssh/id_ed25519.pub`) — placed on the server in `~/.ssh/authorized_keys`

When you connect, the server challenges your client, the client proves it holds the private key, and you're in — no password needed.

```bash
ssh user@hostname           # connect
ssh -i ~/.ssh/mykey user@host   # use specific key
ssh -p 2222 user@host       # non-default port
ssh -L 8080:localhost:80 user@host  # local port forwarding
```

### SSH Config File

`~/.ssh/config` lets you define shortcuts:

```
Host myserver
    HostName 203.0.113.10
    User ubuntu
    IdentityFile ~/.ssh/my_key
    Port 22
```

Then just: `ssh myserver`

### DNS — Domain Name System

DNS is the internet's phone book. It translates human-readable names (`google.com`) to IP addresses (`142.250.80.46`).

**Resolution flow:**

```
Browser asks: "What is the IP for google.com?"
  → OS checks /etc/hosts
  → OS asks configured DNS resolver (e.g. 8.8.8.8)
    → Resolver checks its cache
    → Resolver asks root DNS servers
    → Root refers to .com nameservers
    → .com nameservers refer to google.com nameservers
    → google.com nameserver returns: 142.250.80.46
Answer returned to browser
```

**Key DNS record types:**

| Record | Purpose | Example |
|---|---|---|
| `A` | Name → IPv4 address | `google.com → 142.250.80.46` |
| `AAAA` | Name → IPv6 address | |
| `CNAME` | Alias to another name | `www → myapp.example.com` |
| `MX` | Mail server for domain | |
| `TXT` | Arbitrary text (used for SPF, verification) | |
| `NS` | Nameservers for a domain | |

### TLS — Transport Layer Security

TLS (formerly SSL) encrypts traffic between client and server. When you see `https://`, TLS is in use.

How it works (simplified):
1. Client connects, server presents its **certificate**
2. Certificate is signed by a trusted **Certificate Authority (CA)**
3. Client verifies the signature chain — is this cert trusted?
4. Both sides negotiate an **encryption key** (TLS handshake)
5. All subsequent data is encrypted

A certificate contains: domain name, expiry date, public key, CA signature.

---

## Lab · ~50 min

### Step 1 — Generate SSH keys

```bash
# Generate an Ed25519 key pair (preferred over RSA)
ssh-keygen -t ed25519 -C "devops-month" -f ~/.ssh/devops_month

# View the generated files
ls -la ~/.ssh/
cat ~/.ssh/devops_month.pub   # public key — safe to share

# Set correct permissions (SSH is strict about this)
chmod 700 ~/.ssh
chmod 600 ~/.ssh/devops_month
chmod 644 ~/.ssh/devops_month.pub
```

### Step 2 — SSH to localhost (self-test)

```bash
# Copy the public key to your own authorized_keys
cat ~/.ssh/devops_month.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Confirm SSH is running
sudo systemctl status ssh   # or sshd

# SSH to localhost using your new key
ssh -i ~/.ssh/devops_month localhost

# If it works, exit
exit
```

### Step 3 — Create SSH config

```bash
cat > ~/.ssh/config << 'EOF'
Host localhost-test
    HostName 127.0.0.1
    User YOUR_USERNAME
    IdentityFile ~/.ssh/devops_month
    StrictHostKeyChecking no
EOF

chmod 600 ~/.ssh/config

# Now connect using the alias
ssh localhost-test
exit
```

### Step 4 — DNS lookups

```bash
# Basic lookup
dig google.com              # full DNS response
dig google.com A            # only A records
dig google.com MX           # mail records
dig +short google.com       # just the IP

# Reverse lookup (IP → name)
dig -x 8.8.8.8

# Query a specific DNS server
dig @1.1.1.1 google.com

# Check your system's DNS configuration
cat /etc/resolv.conf
cat /etc/hosts
```

### Step 5 — Inspect TLS certificates

```bash
# View certificate for a website
openssl s_client -connect google.com:443 -servername google.com </dev/null 2>/dev/null \
    | openssl x509 -noout -text | head -40

# Just get expiry and subject
echo | openssl s_client -connect github.com:443 2>/dev/null \
    | openssl x509 -noout -dates -subject

# Test with curl
curl -v https://google.com 2>&1 | grep -E "subject|issuer|expire"
```

---

## Assignment

1. Add your `devops_month` public key to your GitHub account (Settings → SSH keys). Test with `ssh -T git@github.com`. Paste the response.
2. Run `dig github.com`. What is the IP returned? What TTL does the record have, and what does TTL mean?
3. What DNS server is your machine currently using? Where is this configured?
4. Check the TLS certificate for `github.com`. When does it expire? Who issued it?

---

## Further Reading

- [How SSH works — illustrated](https://www.cloudflare.com/learning/access-management/what-is-ssh/)
- [DNS explained — Cloudflare](https://www.cloudflare.com/learning/dns/what-is-dns/)
- `man ssh_config`, `man dig`, `man openssl`
