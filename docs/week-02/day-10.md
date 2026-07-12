# Day 10 · Networking III — SSH, Tunnels & Firewalls

> You can address a machine and resolve its name — now you need to *get into it, safely*. **SSH** is the single most-used tool in a DevOps engineer's day: every server, every deploy, every debug session starts with it. Today you'll go past "type a password" to key-based login, config shortcuts, a hardened server, encrypted **tunnels**, and a **firewall** that closes every door you're not using. We finish with what a **VPN** adds on top.

## Learning Objectives

- See first-hand *why* **telnet** was abandoned and **SSH** took over
- Generate and use SSH **key pairs** instead of passwords
- Streamline connections with `~/.ssh/config`
- Move files over SSH with `scp` and `rsync`
- **Harden** an SSH server — disable passwords and root login
- Reach an unexposed service through an SSH **tunnel** (port forwarding)
- Lock a host down to only the ports it needs with **`ufw`**
- Explain what a **VPN** is and how it differs from an SSH tunnel

---

## Theory · ~20 min

### 1. From telnet to SSH — why the switch happened

For decades you reached a remote Unix box with **telnet**, an early protocol that opened a plain TCP connection to port 23 and dropped you at a login prompt:

```text
$ telnet 192.168.1.50
Trying 192.168.1.50...
Connected to 192.168.1.50.
Escape character is '^]'.

Ubuntu 8.04.1
login: alice
Password:                 ← you type your password here
Last login: Tue Jan  9 14:02:11 from 192.168.1.7
alice@server:~$           ← a full interactive shell
```

It was simple and it worked — and it was **dangerously insecure**. Everything in that session, *including the password*, crossed the network as **plaintext**. Anyone able to watch the traffic — a coworker on the same LAN, a compromised switch, your ISP — could read it with a tool as basic as the `tcpdump` you already know. (Telnet is obsolete and we don't use it in this course — but you'll reproduce that exact leak with `nc` in Step 8.) Telnet had two more fatal flaws:

- **No proof of who you're talking to** — it never verifies the server's identity, so an attacker who redirects your traffic can impersonate the box and harvest your credentials (a *man-in-the-middle* attack).
- **No tamper protection** — nothing detects if the bytes are altered in transit.

**SSH** (Secure Shell) fixed all three at once, which is why it *completely* replaced telnet for logins:

| | telnet | SSH |
|---|---|---|
| Traffic | Plaintext — password visible | Encrypted end to end |
| Server identity | Unverified | Verified via host key |
| Tamper detection | None | Built in |
| Auth options | Password only | Password **or** key pairs |

Anything you do on a server now, you do over SSH:

```bash
ssh user@host            # log in (encrypted)
ssh user@host 'uptime'   # run one command and return
```

!!! note "The host-key prompt is SSH proving the server's identity"
    The first time you connect, SSH shows the server's **host key fingerprint** — the "The authenticity of host … can't be established" prompt. Accept it once and SSH records it in `~/.ssh/known_hosts`; if that key ever changes, SSH loudly refuses to connect, catching the impersonation that telnet couldn't.

### 2. Keys beat passwords

Passwords can be guessed, phished, and brute-forced. **Key-based authentication** replaces them with a **key pair**:

- **Private key** (`~/.ssh/id_ed25519`) — stays on *your* machine, secret, never shared.
- **Public key** (`~/.ssh/id_ed25519.pub`) — copied onto the *server*, into `~/.ssh/authorized_keys`. Safe to hand out.

```
You (private key)                    Server (your public key on file)
      │  "I want in"                        │
      │ ───────────────────────────────────▶
      │            challenge                │
      │ ◀───────────────────────────────────
      │  signs it with the private key      │
      │ ───────────────────────────────────▶  verifies with the public key → in
```

The private key never crosses the wire. This is why every cloud provider hands you a key pair, not a password, for a new server.

!!! tip "Ed25519 over RSA"
    Prefer `ssh-keygen -t ed25519` — the keys are short, fast, and modern. Only fall back to `rsa -b 4096` for ancient servers that don't support Ed25519.

### 3. `~/.ssh/config` — stop retyping

Instead of long `ssh -i ~/.ssh/key -p 2222 ubuntu@203.0.113.10` commands, define a **host alias** once:

```
Host web
    HostName 203.0.113.10
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/devops_month
```

Then simply `ssh web`. `scp`, `rsync`, and `git` all read this file too.

### 4. Moving files: `scp` and `rsync`

| Tool | Use it for |
|---|---|
| `scp` | Quick one-off copies over SSH — `scp file user@host:/path` |
| `rsync` | Syncing directories — only transfers **differences**, resumable, ideal for deploys |

### 5. Hardening — shut the easy doors

An SSH server reachable from the internet is probed constantly by bots. Two settings in `/etc/ssh/sshd_config` stop the overwhelming majority of attacks:

| Setting | Value | Why |
|---|---|---|
| `PasswordAuthentication` | `no` | No passwords to guess — keys only |
| `PermitRootLogin` | `no` | Force login as a normal user, then `sudo` |

!!! danger "Don't lock yourself out"
    Before you set `PasswordAuthentication no`, **confirm key login works in a second terminal.** If keys aren't set up and you disable passwords, you can be locked out of a remote box for good. On a cloud VM, always keep one working session open while you change SSH settings.

### 6. Tunnels — reach what isn't exposed

A server's database on port 5432 should **not** be open to the internet. But you still need to reach it from your laptop. An SSH **local port forward** tunnels it through your existing SSH connection, encrypted:

```bash
ssh -L 5433:localhost:5432 user@host
#      │    │         │
#      │    │         └ the target, as seen FROM the server (its own localhost)
#      │    └ port/host on the server side to connect onward to
#      └ port on YOUR machine to open
```

Now `localhost:5433` on your laptop *is* the server's private database — no port opened to the world. This is how you safely reach internal dashboards, databases, and admin panels.

### 7. Firewalls — default deny

Hardening SSH secures one door; a **firewall** decides which doors exist at all. Ubuntu's **`ufw`** (Uncomplicated Firewall) is a friendly front-end to the kernel's netfilter. The golden rule: **deny everything inbound, then allow only what you need** (22, 80, 443).

### 8. VPNs — extend the private network

An SSH tunnel forwards *one port*. A **VPN** (Virtual Private Network) goes further: it puts your machine *onto* a remote private network entirely, as if you were plugged in there — every app, every port, transparently. Companies use it so employees reach internal systems from anywhere; you'll meet **WireGuard** (modern, fast) and **OpenVPN** (older, ubiquitous).

| | SSH tunnel | VPN |
|---|---|---|
| Scope | One (or a few) forwarded ports | The whole network, all apps |
| Setup | Nothing extra — uses SSH | A daemon + keys on both ends |
| Feels like | "This local port is that remote service" | "I'm on the office network" |

---

## Lab · ~50 min

Work **inside your Vagrant VM**. We'll SSH from the VM back **into itself** (`localhost`) — every command is identical to a real remote server, just without needing a second machine.

### Step 1 — Generate a key pair

```bash
ssh-keygen -t ed25519 -C "devops-month" -f ~/.ssh/devops_month -N ""
#  -C comment   -f output file   -N "" no passphrase (fine for a lab)

ls -l ~/.ssh/devops_month*        # private key + .pub public key
cat ~/.ssh/devops_month.pub       # the public half — safe to share
```

### Step 2 — Install the key and log in with it

```bash
# Put the PUBLIC key into authorized_keys (what a server checks on login)
ssh-copy-id -i ~/.ssh/devops_month.pub localhost
# (accept the fingerprint; enter your vagrant password this one time)

# Now log in with the KEY — no password prompt
ssh -i ~/.ssh/devops_month localhost 'whoami; echo "logged in with a key"'
```

### Step 3 — Create an SSH config shortcut

```bash
cat >> ~/.ssh/config << 'EOF'

Host self
    HostName 127.0.0.1
    User vagrant
    IdentityFile ~/.ssh/devops_month
EOF
chmod 600 ~/.ssh/config

ssh self 'hostname'               # the whole connection, in one short word
```

### Step 4 — Move files with scp and rsync

```bash
echo "deploy me" > ~/artifact.txt

scp ~/artifact.txt self:/tmp/artifact.txt        # copy one file over SSH
ssh self 'cat /tmp/artifact.txt'

mkdir -p ~/site && echo "v1" > ~/site/index.html
rsync -av ~/site/ self:/tmp/site/                # sync a directory
echo "v2" > ~/site/index.html
rsync -av ~/site/ self:/tmp/site/                # note: only the CHANGED file transfers
```

### Step 5 — Harden the SSH server (safely)

You have a working key (Step 2), so it's now safe to turn off passwords. We use a drop-in file rather than editing the main config:

```bash
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
PasswordAuthentication no
PermitRootLogin no
EOF

sudo sshd -t                      # ALWAYS test the config before applying
sudo systemctl reload ssh

ssh self 'echo "key login still works after hardening"'   # proof you're not locked out
```

!!! note "Why a `.d/` drop-in?"
    Dropping a small file in `sshd_config.d/` leaves the vendor's main config untouched and makes your change obvious and reversible — the same pattern you saw with Nginx `sites-available` and cron. To undo: `sudo rm /etc/ssh/sshd_config.d/99-hardening.conf && sudo systemctl reload ssh`.

### Step 6 — Build an SSH tunnel

Start a "private" service bound to loopback only, then reach it through a tunnel — exactly how you'd reach a locked-down database.

```bash
# A pretend internal service, listening on 127.0.0.1:8000 (not exposed anywhere)
python3 -m http.server 8000 --bind 127.0.0.1 &
SERVICE_PID=$!

# Forward YOUR port 9999 → the service's 8000, through SSH
ssh -f -N -L 9999:localhost:8000 self
#   -f background   -N no shell, just the tunnel

curl -s http://localhost:9999/ | head -5         # you reached 8000 THROUGH the tunnel

# Clean up
pkill -f "ssh -f -N -L 9999"
kill $SERVICE_PID
```

### Step 7 — Lock the box down with `ufw`

```bash
sudo ufw default deny incoming        # deny everything inbound...
sudo ufw default allow outgoing       # ...allow the box to reach out
sudo ufw allow 22/tcp                 # keep SSH open FIRST (or you lock yourself out)
sudo ufw allow 80/tcp                 # HTTP — for tomorrow's Nginx
sudo ufw allow 443/tcp                # HTTPS

sudo ufw enable                       # turn it on (answer 'y')
sudo ufw status verbose               # review the rules
```

!!! warning "Order matters — allow 22 before enabling"
    On a **real remote server**, enabling `ufw` before allowing port 22 cuts your own SSH session and locks you out. Always `allow 22/tcp` first. (On this Vagrant VM you'd still have `vagrant ssh` via the console, but build the safe habit now.)

### Step 8 — The payoff: watch a plaintext login leak (and SSH not)

You've spent the day securing SSH. Now *see* the problem it solves — with the `tcpdump` and `nc` from Day 08. We'll "log in" to a throwaway plaintext service and catch the password on the wire, then repeat over SSH. Open **three terminals** into the VM.

```bash
# (Day 08 installed these; run again if needed)
sudo apt install -y tcpdump netcat-openbsd
```

**Terminal A — watch the wire** (`-A` prints packet payloads as text):

```bash
sudo tcpdump -i lo -nA 'tcp port 2323'
```

**Terminal B — a stand-in login server** (`nc` listening — exactly how the old plaintext login daemons behaved on the wire):

```bash
nc -l 2323
```

**Terminal C — connect as the client and "log in":**

```bash
nc 127.0.0.1 2323
```

Type a fake password and press Enter:

```
hunter2
```

Now look at **Terminal A** — `hunter2` shows up **in the clear** inside the captured packet. Anyone watching the network just read the password. `Ctrl-C` stops the capture (and closes each `nc`).

Now the contrast — capture an **SSH** connection instead:

```bash
sudo tcpdump -i lo -nA 'tcp port 22' -c 25     # grab 25 packets, then stop
```

In another terminal, trigger some SSH traffic:

```bash
ssh self 'echo my-secret-command'
```

Scroll Terminal A's SSH capture: it's **encrypted gibberish** — no password, no command, nothing readable. Same wire, completely different safety. *That* is why the world switched.

```bash
pkill -f "nc -l 2323"      # clean up the stand-in server
```

---

## Advanced Topics

- **SSH agent & agent forwarding** — load a key once, and use it on a jump host without copying it there → [`ssh-agent`](https://www.ssh.com/academy/ssh/agent) · `ssh -A`
- **Jump/bastion hosts** — reach a private server through a public gateway with `ProxyJump` → [`man ssh_config` — ProxyJump](https://man7.org/linux/man-pages/man5/ssh_config.5.html)
- **`fail2ban`** — auto-ban IPs that hammer your SSH port → [fail2ban.org](https://www.fail2ban.org/)
- **Set up WireGuard** — stand up a real modern VPN between two peers → [WireGuard quick start](https://www.wireguard.com/quickstart/)
- **`iptables` / `nftables`** — the raw firewall layer that `ufw` sits on top of → [ArchWiki — nftables](https://wiki.archlinux.org/title/Nftables)

---

## Assignment

1. **A deploy-ready connection.** Set up a *new* SSH host alias called `staging` in `~/.ssh/config` (point `HostName` at `127.0.0.1` for now, using your `devops_month` key). Then write a **one-line command** that uses `rsync` over that alias to deploy your `~/site/` directory to `/tmp/staging-site/`, and a second command that runs `ls -l /tmp/staging-site/` on the remote via the alias. Paste both commands and their output. *This is literally how you'll push a build to a server later.*

2. **Justify a firewall.** Imagine a public web server that runs SSH, Nginx (80/443), and a Postgres database (5432) used only by the app on the same box. Write the exact `ufw` commands you'd apply, and in two or three sentences explain **why 5432 should not be allowed** and how the app still reaches the database without it. (Hint: think about what you built in Step 6.)

---

## Further Reading

- [How SSH works — Cloudflare](https://www.cloudflare.com/learning/access-management/what-is-ssh/)
- [SSH tunneling explained](https://www.ssh.com/academy/ssh/tunneling-example) — local, remote, and dynamic forwards
- [DigitalOcean — SSH essentials](https://www.digitalocean.com/community/tutorials/ssh-essentials-working-with-ssh-servers-clients-and-keys)
- `man ssh`, `man ssh_config`, `man sshd_config`, `man ufw`, `man rsync`
