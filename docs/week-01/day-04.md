# Day 04 · Users, Groups & Permissions

## Learning Objectives

- Understand why Linux is multi-user and how users and groups are modeled
- Create and manage users and groups
- Read and modify ownership and permissions with `chmod` and `chown`
- Translate between symbolic (`rwx`) and numeric (`755`) permissions
- Use a handful of everyday networking commands to check connectivity

---

## Theory · ~20 min

### Why users and groups exist

Unix was built for **shared** machines — one computer, many users. A modern Linux **server** is shared too: by human admins, by service accounts (`www-data`, `postgres`), and by automated pipelines. The permission model gives you:

- **Isolation** — your files are yours; another user can't read or wreck them
- **Least privilege** — a web server runs as an unprivileged account, so a compromise can't own the whole box
- **Accountability** — actions are tied to an identity (`/var/log/auth.log`)

### The user model

Every user has a numeric **UID**; every group a **GID**. Names are just a friendly mapping.

```bash
whoami            # current username
id                # your UID, primary GID, and group memberships
cat /etc/passwd   # all user accounts
cat /etc/group    # all groups
```

Each line in `/etc/passwd` has 7 colon-separated fields:

```
username : x : UID : GID : comment : home_dir : login_shell
vagrant  : x :1000 :1000 :         :/home/vagrant:/bin/bash
```

The `x` means the real password hash lives in `/etc/shadow`, readable only by root.

- **root** (UID 0) is the superuser — it bypasses permission checks. You escalate temporarily with `sudo` instead of logging in as root.
- **System accounts** (low UIDs, e.g. `www-data`) run services, not people. They usually have `nologin` as their shell.
- Every user has one **primary group** and can belong to many **supplementary groups** (e.g. `sudo`, `docker`).

### Permissions: reading `rwxr-xr--`

Every file carries permissions for three classes: **owner (user)**, **group**, and **others**.

```
-rwxr-xr--  1  alice  devs  1234  Jun 01  deploy.sh
│└─┬─┘└─┬─┘└─┬─┘
│  u    g    o
└ type (- file, d dir, l symlink)
```

Each class has three bits:

| Symbol | Meaning | Value | On a directory |
|---|---|---|---|
| `r` | read | 4 | list contents |
| `w` | write | 2 | create/delete entries |
| `x` | execute | 1 | enter / traverse (`cd`) |

So `rwxr-xr--` = **754** (owner 7, group 5, others 4).

!!! note "Beyond the basics"
    Linux also has **special bits** (setuid/setgid/sticky), **ACLs**, and **file attributes** for finer-grained control. You don't need them yet — you'll meet them in today's stretch assignment and in later security work. Master the standard `rwx` model first.

---

## Lab · ~50 min

Work **inside your Vagrant VM** (`vagrant ssh`).

### Step 1 — Inspect the current model

```bash
whoami; id
cut -d: -f1,7 /etc/passwd | grep -v "nologin\|false"   # real login users
grep sudo /etc/group                                    # who can sudo
```

### Step 2 — Create users and a shared group

```bash
sudo groupadd webdev
sudo useradd -m -s /bin/bash alice   # -m creates home, -s sets shell
sudo useradd -m -s /bin/bash bob
sudo usermod -aG webdev alice        # ADD alice to webdev (-a = append!)
sudo usermod -aG webdev bob

id alice
id bob
```

!!! warning "Always use `-aG`, never bare `-G`"
    `usermod -G webdev alice` *replaces* all of alice's supplementary groups with just `webdev` — a classic way to accidentally remove someone from `sudo`. `-aG` **appends**.

Clean up a user when you're done experimenting:

```bash
sudo userdel -r bob      # delete user AND their home directory
```

### Step 3 — chmod: change permissions

```bash
cd ~ && mkdir -p permlab && cd permlab

cat > deploy.sh << 'EOF'
#!/bin/bash
echo "Deploying..."
EOF

ls -l deploy.sh          # no execute bit yet
./deploy.sh              # Permission denied

# Numeric (absolute)
chmod 755 deploy.sh      # rwxr-xr-x
./deploy.sh              # works now
chmod 600 deploy.sh      # rw------- (owner only)
ls -l deploy.sh

# Symbolic (relative)
chmod +x deploy.sh       # add execute for all classes
chmod u+x,go-w deploy.sh # owner +execute, group/other -write
ls -l deploy.sh
```

### Step 4 — chown: change ownership

```bash
echo "quarterly numbers" > report.txt
ls -l report.txt                    # owned by you

sudo chown alice report.txt         # change owner
sudo chown alice:webdev report.txt  # change owner AND group
sudo chown :webdev report.txt       # change group only
ls -l report.txt
```

### Step 5 — See least-privilege in action

```bash
chmod 640 report.txt                # rw-r----- : owner rw, group r, others none
ls -l report.txt

# 'others' cannot read it — prove it as a different user
sudo -u alice cat report.txt        # alice is owner → works
sudo useradd -m carol 2>/dev/null
sudo -u carol cat report.txt        # carol is 'other' → Permission denied
```

### Step 6 — Everyday networking checks

You'll go deep on networking in Week 2. For now, learn the quick "is it reachable?" toolkit:

```bash
ip a                     # this machine's network interfaces & IP addresses
ping -c 3 8.8.8.8        # can I reach the internet? (-c 3 = 3 packets)
ping -c 3 google.com     # does DNS resolve AND is it reachable?
dig google.com +short    # what IP does this name resolve to?
curl -I https://example.com   # fetch just the HTTP response headers
```

If `ping 8.8.8.8` works but `ping google.com` doesn't, the network is fine but **DNS** is broken — a distinction you'll use constantly.

---

## Assignment

In `my-progress/day-04.md`:

1. **Hands-on — a real permissions scenario:** Create a group `team` and two users in it. Create a directory `/srv/team` owned by `root:team` and a file inside it. Set permissions so that:
   - members of `team` can **read and write** files in the directory,
   - **other** users can do nothing.

   Prove it works: as one team member, create a file; as a **non-member**, try to read it and show the "Permission denied". Paste every command and its output, and give the numeric permission you chose for the directory and why.

   *Stretch (the advanced controls we skipped):* make it a proper shared dropbox where members can add files but can **only delete their own** — research and apply the **setgid** and **sticky** bits (`chmod 2775`, `chmod +t`). Prove that user A cannot delete user B's file.

---

## Further Reading

- `man chmod`, `man chown`, `man usermod`, `man useradd`
- [chmod-calculator.com](https://chmod-calculator.com/) — visualize numeric ↔ symbolic
- [Understanding /etc/passwd](https://www.cyberciti.biz/faq/understanding-etcpasswd-file-format/)
- [ArchWiki: File permissions and attributes](https://wiki.archlinux.org/title/File_permissions_and_attributes) — special bits, ACLs, and attributes when you're ready
