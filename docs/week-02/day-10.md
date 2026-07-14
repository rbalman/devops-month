# Day 3 · Networking III — SSH & Firewalls

> You can address a machine and resolve its name — now you need to *get into it, safely*. **SSH** is the single most-used tool in a DevOps engineer's day: every server, every deploy, every debug session starts with it. Today you'll go past "type a password" to key-based login, config shortcuts, and a hardened server, then how teams reach fleets of machines (**VPNs** and **bastion** hosts) — and finally a **firewall** that closes every door you're not using.

## Learning Objectives

- Hand-type a protocol with **telnet** (HTTP, SMTP) — and see why plaintext login gave way to **SSH**
- Generate SSH **key pairs** and authorize them via `~/.ssh/authorized_keys`
- Streamline connections with `~/.ssh/config`, and move files with `scp` and `rsync`
- **Harden** an SSH server — disable passwords and root login
- Understand how **VPNs** and **bastion hosts** give teams access at scale
- Lock a host down to only the ports it needs with **`ufw`**

---

## Prerequisites

Today's lab runs on a single Ubuntu VM. Save this as a `Vagrantfile`, then `vagrant up` and `vagrant ssh` in — you'll run the whole lab from inside this VM, SSHing to itself as a stand-in for a remote server.

```ruby
Vagrant.configure("2") do |config|
  config.vm.box      = "bento/ubuntu-24.04"
  config.vm.hostname = "server"

  config.vm.network "private_network", ip: "192.168.56.11"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "server"
    vb.memory = 1024
    vb.cpus   = 1
  end
end
```

```bash
vagrant up        # create/start the VM
vagrant ssh       # log in — run the whole lab from here
```

---

## Theory · ~20 min

### 1. Telnet — typing a protocol by hand

A protocol like HTTP or SMTP is just **agreed-upon text sent over a TCP connection**. Because `telnet` gives you a raw TCP pipe plus your keyboard, you can *be the client* and type that text yourself — a genuinely handy way to poke at a service and see exactly what it says back. Ask a web server for a page over **HTTP** (port 80):

```text
$ telnet example.com 80
GET / HTTP/1.1        ← request line: method, path, HTTP version
Host: example.com     ← required header
                      ← blank line ends the request → server sends the page back
```

Or hand a message to a mail server over SMTP (port 25) — each line gets a numeric reply code (`250 OK`, `550 rejected`…):

```text
$ telnet mail.example.com 25
HELO myclient.local
MAIL FROM:<you@example.com>      ← the < > are required by the SMTP grammar
RCPT TO:<friend@example.com>
DATA
Subject: Hi from telnet

Typed by hand over TCP.
.                                ← a lone dot on its own line ends the message
QUIT
```

The server can't tell your keystrokes from a real browser or mail client — it only sees bytes on the socket, and that's the whole point: **a protocol is just agreed-upon text over a TCP stream.** (Two gotchas that bite everyone: SMTP requires the `< >` around addresses, and pressing `Ctrl-]` drops you to a local `telnet>` prompt — telnet's own command mode — where `quit` closes a stuck session.)

!!! note "Telnet was also how you *logged into* servers — and why SSH replaced it"
    Before SSH, `telnet <host> 23` dropped you straight into a login shell on a remote machine — it was *the* original remote-access tool. The fatal flaw: **everything, including your password, crossed the network as plaintext**, with no way to verify the server's identity or detect tampering. **SSH** encrypts the entire session, proves the server's identity with a host key, and adds key-based auth — which is why it *completely* replaced telnet for logins.

### 2. SSH — secure login and file transfer

Anything you do on a server now, you do over **SSH** (Secure Shell): a single encrypted, authenticated channel that carries interactive shells, one-off commands, and file copies.

```bash
ssh user@host            # log in (encrypted interactive shell)
ssh user@host 'uptime'   # run one command and return
```

!!! note "The host-key prompt is SSH proving the server's identity"
    The first time you connect, SSH shows the server's **host key fingerprint** — the "The authenticity of host … can't be established" prompt. Accept it once and SSH records it in `~/.ssh/known_hosts`; if that key ever changes, SSH loudly refuses to connect, catching the impersonation that telnet couldn't. (After a *legitimate* change — a rebuilt server — clear the stale entry with `ssh-keygen -R <host>` and reconnect.)

#### Keys beat passwords

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

!!! note "`~/.ssh/authorized_keys` — the server's guest list"
    On the server, the account you log in as has a `~/.ssh/authorized_keys` file: **one public key per line**, listing every key allowed to log in as that user. On each connection `sshd` checks your signature against every line in it. Adding a line **grants** access; deleting it **revokes** access — no password ever involved. (You'll add your own key to it in Step 2.)

!!! tip "Ed25519 over RSA"
    Prefer `ssh-keygen -t ed25519` — the keys are short, fast, and modern. Only fall back to `rsa -b 4096` for ancient servers that don't support Ed25519.

#### `~/.ssh/config` — stop retyping

Instead of long `ssh -i ~/.ssh/key -p 2222 ubuntu@203.0.113.10` commands, define a **host alias** once:

```
Host web
    HostName 203.0.113.10
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/devops_month
```

Then the whole thing collapses to one word:

```bash
ssh web                       # ≡ ssh -i ~/.ssh/devops_month -p 2222 ubuntu@203.0.113.10
ssh web 'uptime'              # run a one-off command over the alias
scp report.txt web:/tmp/      # scp, rsync, and git read this file too
```

#### Moving files: `scp` and `rsync`

| Tool | Use it for |
|---|---|
| `scp` | Quick one-off copies over SSH — `scp file user@host:/path` |
| `rsync` | Syncing directories — only transfers **differences**, resumable, ideal for deploys |

#### Hardening — shut the easy doors

An SSH server reachable from the internet is probed constantly by bots. Two settings in `/etc/ssh/sshd_config` stop the overwhelming majority of attacks:

| Setting | Value | Why |
|---|---|---|
| `PasswordAuthentication` | `no` | No passwords to guess — keys only |
| `PermitRootLogin` | `no` | Force login as a normal user, then `sudo` |

!!! danger "Don't lock yourself out"
    Before you set `PasswordAuthentication no`, **confirm key login works in a second terminal.** If keys aren't set up and you disable passwords, you can be locked out of a remote box for good. On a cloud VM, always keep one working session open while you change SSH settings.

### 3. VPNs — extend the private network

A **VPN** (Virtual Private Network) puts your machine *onto* a remote private network entirely, as if you were plugged in there — every app, every port, transparently. Contrast that with a single forwarded port (SSH tunneling — an advanced topic below), which reaches just *one* service. Companies use a VPN so employees reach internal systems from anywhere; you'll meet **WireGuard** (modern, fast) and **OpenVPN** (older, ubiquitous).

| | SSH tunnel | VPN |
|---|---|---|
| Scope | One (or a few) forwarded ports | The whole network, all apps |
| Setup | Nothing extra — uses SSH | A daemon + keys on both ends |
| Feels like | "This local port is that remote service" | "I'm on the office network" |

### 4. Bastion / jump hosts — one guarded front door

You don't expose every server to the internet. Instead, a single hardened, closely-watched host — the **bastion** (or **jump host**) — is the *only* box reachable from outside on SSH. To reach anything private, you hop *through* it:

```
You ──SSH──▶ Bastion (public IP, port 22)  ──SSH──▶  app server (private)
                                            └──SSH──▶  database  (private)
```

Only the bastion needs a public address and an open port; every server behind it stays unreachable from the internet, shrinking your attack surface to one heavily-monitored door. SSH makes the hop in a single command with **`ProxyJump`** — `ssh -J bastion user@internal-host` — without leaving your keys on the bastion.

### 5. Firewalls — default deny with `ufw`

Hardening SSH secures one door; a **firewall** decides which doors exist at all. Ubuntu's **`ufw`** (Uncomplicated Firewall) is a friendly front-end to the kernel's **netfilter**. It's **stateful** — replies to connections you started are allowed back automatically, so you only write rules for *new inbound* traffic. The golden rule: **default deny inbound, allow outbound, then open only the ports you serve.**

```bash
sudo ufw allow 22/tcp             # ALLOW SSH FIRST — by port+protocol (or: ufw allow OpenSSH, see `ufw app list`)
sudo ufw allow 80,443/tcp         # HTTP + HTTPS together
sudo ufw allow from 203.0.113.7 to any port 5432   # one trusted IP (or a CIDR like 10.0.0.0/24)
sudo ufw limit 22/tcp             # rate-limit SSH: block an IP after 6 hits in 30s
sudo ufw default allow outgoing   # let the box reach out (updates, DNS…)

# ⚠ CAUTION — run ONLY after 22 is allowed above; skip it and you lock yourself out:
#   sudo ufw default deny incoming    # closes every inbound port not explicitly allowed
```

Rules added while ufw is **inactive** are only staged — nothing is enforced until `enable`. So build, preview, *then* activate — and **always allow 22 before enabling**, or you cut your own session:

```bash
sudo ufw show added        # list the rules you've queued
sudo ufw --dry-run enable  # print the exact ruleset enabling WOULD apply — changes nothing
sudo ufw enable            # activate

sudo ufw status numbered   # active rules, with index numbers
sudo ufw delete 3          # remove rule #3
```

!!! note "Host firewall vs. network firewall"
    `ufw` guards **this one machine**. Clouds add a **network firewall** in front of the VM — AWS **security groups**, GCP **firewall rules**, Azure **NSGs** — filtering traffic before it reaches the box. They're independent, so a port must be open in **both** to be reachable: run the cloud firewall as the perimeter and `ufw` as a local backstop.

!!! tip "ufw — points to remember"
    - **First match wins.** Rules are checked top-to-bottom and the *first* one that matches decides; the **default policy** applies only if none do. New rules append to the **end** — to place one earlier, use `sudo ufw insert 1 <rule>`.
    - **Specific before general.** A `deny` for one IP must sit *above* a broader `allow` on the same port, or the `allow` matches first and the `deny` never runs.
    - **`allow 22` opens it to the whole internet.** Scope a port with `from <ip/CIDR>` when only certain sources should reach it.
    - **Stateful — inbound rules only.** Replies to connections the box started are allowed back automatically; you never write outbound rules for them.
    - **`deny` vs `reject`.** `deny` drops silently (the sender just times out); `reject` sends back a refusal (a faster, clearer failure).
    - **Persists across reboots** once enabled. Run `sudo ufw reload` after editing rules, and don't hand-edit raw `iptables` alongside ufw — it owns those chains.

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

### Step 2 — Authorize the key and log in with it

Add your **public** key to `~/.ssh/authorized_keys` — the file `sshd` checks on every login (one allowed key per line):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat ~/.ssh/devops_month.pub >> ~/.ssh/authorized_keys   # append the PUBLIC key as an authorized login
chmod 600 ~/.ssh/authorized_keys

# Now log in with the KEY — no password prompt (accept the host-key prompt the first time)
ssh -i ~/.ssh/devops_month localhost 'whoami; echo "logged in with a key"'
```

!!! note "On a *real* remote server, it's the same copy-paste — there's no magic"
    Authorizing a key is **just text**. You did `cat ...pub >> authorized_keys` here because the file is on this machine. On a *remote* server you do the identical thing: copy the single line `cat ~/.ssh/devops_month.pub` prints, and paste it onto its own line in that server's `~/.ssh/authorized_keys` (through your cloud provider's web console, or an already-open session). That's the whole process. The `ssh-copy-id user@host` command just automates this exact paste for you — convenient, but it's nothing more than appending your public-key line.

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

### Step 6 — Lock the box down with `ufw`

```bash
sudo ufw allow 22/tcp                 # ALLOW SSH FIRST — or enabling locks you out
sudo ufw allow 80,443/tcp             # HTTP + HTTPS (for tomorrow's Nginx)
sudo ufw limit 22/tcp                 # rate-limit SSH: block an IP after 6 hits in 30s

sudo ufw enable                       # turn it on — inbound denied by default, outbound stays open
sudo ufw status verbose               # review the rules

curl -sI https://google.com | head -1 # confirm the box can still reach OUT (default allow outgoing)
```

!!! warning "Order matters — allow 22 before enabling"
    On a **real remote server**, enabling `ufw` before allowing port 22 cuts your own SSH session and locks you out. Always `allow 22/tcp` first. (On this Vagrant VM you'd still have `vagrant ssh` via the console, but build the safe habit now.)

---

## Advanced Topics

- **SSH agent & agent forwarding** — load a key once, and use it on a jump host without copying it there → [`ssh-agent`](https://www.ssh.com/academy/ssh/agent) · `ssh -A`
- **Jump/bastion hosts** — reach a private server through a public gateway with `ProxyJump` → [`man ssh_config` — ProxyJump](https://man7.org/linux/man-pages/man5/ssh_config.5.html)
- **SSH tunnels (local port forwarding)** — reach a service that isn't exposed to the internet (a locked-down database, an internal dashboard) *through* your SSH connection, encrypted: `ssh -L 5433:localhost:5432 user@host` makes your `localhost:5433` behave as the server's private `5432` → [SSH tunneling explained](https://www.ssh.com/academy/ssh/tunneling-example)
- **`fail2ban`** — auto-ban IPs that hammer your SSH port → [fail2ban.org](https://www.fail2ban.org/)
- **Set up WireGuard** — stand up a real modern VPN between two peers → [WireGuard quick start](https://www.wireguard.com/quickstart/)
- **`iptables` / `nftables`** — the raw firewall layer that `ufw` sits on top of → [ArchWiki — nftables](https://wiki.archlinux.org/title/Nftables)

---

## Assignment

1. **Prove the lock works.** You hardened SSH in Step 5. Now *see* it: try to log in with a password instead of your key — `ssh -o PubkeyAuthentication=no vagrant@localhost` — and paste what happens. In one sentence, explain why the server turns you away. *(Satisfying part: you're watching your own hardening do its job.)*

2. **You're the bouncer.** A single server runs SSH, a website (80/443), and a private Postgres database (5432) that only the app on that same box uses. Write the `ufw allow` commands you'd run to open the right doors — then in **one sentence** say who you turned away at 5432, and why the app can still reach its database anyway.

---

## Further Reading

- [How SSH works — Cloudflare](https://www.cloudflare.com/learning/access-management/what-is-ssh/)
- [SSH tunneling explained](https://www.ssh.com/academy/ssh/tunneling-example) — local, remote, and dynamic forwards
- [DigitalOcean — SSH essentials](https://www.digitalocean.com/community/tutorials/ssh-essentials-working-with-ssh-servers-clients-and-keys)
- `man ssh`, `man ssh_config`, `man sshd_config`, `man ufw`, `man rsync`
