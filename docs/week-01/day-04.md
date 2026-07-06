# Day 04 · Users, Groups & Permissions

## Learning Objectives

- Understand why Linux is multi-user and how users and groups are modeled
- Read and modify ownership and permissions with `chmod` and `chown`
- Translate between symbolic (`rwx`) and numeric (`755`) permissions
- Recognize advanced controls: special bits, ACLs, and file attributes

---

## Theory · ~25 min

### Why users and groups exist

Unix was built in the 1970s for **shared** machines — one physical computer used by many people at once. That shaped a permission model that's still exactly what we need today, because a modern Linux **server** is also shared: by human admins, by service accounts (`www-data`, `postgres`), and by automated pipelines.

The goals are the same as fifty years ago:

- **Isolation** — your files are yours; another user can't read or wreck them
- **Least privilege** — a web server runs as an unprivileged account, so a compromise can't own the whole box
- **Accountability** — actions are tied to an identity (`/var/log/auth.log`)

### The user model

Every user has a numeric **UID**; every group a **GID**. Names are just a friendly mapping.

```bash
whoami            # current username
id                # your UID, primary GID, and all group memberships
cat /etc/passwd   # all user accounts
cat /etc/group    # all groups
```

Each line in `/etc/passwd` has 7 colon-separated fields:

```
username : x : UID : GID : comment : home_dir : login_shell
vagrant  : x :1000 :1000 :         :/home/vagrant:/bin/bash
```

The `x` means the real password hash lives in `/etc/shadow`, readable only by root.

- **root** (UID 0) is the superuser — it bypasses permission checks. You escalate temporarily with `sudo` rather than logging in as root.
- **System accounts** (low UIDs, e.g. `www-data`, `sshd`) run services, not people. They usually have `/usr/sbin/nologin` as their shell so nobody can log in as them.
- Every user has one **primary group** and can belong to many **supplementary groups** (e.g. `sudo`, `docker`).

Managing them:

```bash
sudo useradd -m -s /bin/bash alice   # create user with home + bash
sudo passwd alice                    # set password
sudo groupadd devs                   # create a group
sudo usermod -aG devs alice          # ADD alice to group devs (-a = append!)
sudo userdel -r alice                # delete user and home
```

!!! warning "Always use `-aG`, never bare `-G`"
    `usermod -G devs alice` *replaces* all of alice's supplementary groups with just `devs` — a classic way to accidentally remove someone from `sudo`. `-aG` **appends**.

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

### chmod — change permissions

```bash
# Numeric (absolute)
chmod 755 script.sh      # rwxr-xr-x
chmod 644 config.txt     # rw-r--r--
chmod 600 secret.key     # rw------- (owner only)

# Symbolic (relative)
chmod +x script.sh       # add execute for all classes
chmod u+x,go-w file      # owner +execute, group/other -write
chmod -R g+w shared/     # recurse into a directory tree
```

### chown — change ownership

```bash
sudo chown alice file.txt          # change owner
sudo chown alice:devs file.txt     # change owner AND group
sudo chown :devs file.txt          # change group only
sudo chown -R www-data:www-data /var/www   # recurse
```

### Advanced concepts

You won't reach for these daily, but you must recognize them — they explain "why can't I access this?" mysteries and show up in security reviews.

#### Special permission bits

Beyond `rwx` there are three special bits, shown as a 4th (leading) octal digit:

| Bit | Octal | On a file | On a directory |
|---|---|---|---|
| **setuid** | 4000 | run as the file's **owner** (e.g. `passwd` runs as root) | — |
| **setgid** | 2000 | run as the file's **group** | new files inherit the dir's group |
| **sticky** | 1000 | — | only the **owner** of a file can delete it (used on `/tmp`) |

```bash
ls -l /usr/bin/passwd     # -rwsr-xr-x  → the 's' is setuid
ls -ld /tmp               # drwxrwxrwt  → the 't' is the sticky bit
chmod 2775 shared/        # setgid: files created inside inherit group
chmod +t shared/          # add sticky bit
```

An `s` where an `x` would be means the setuid/setgid bit is on. Setuid root binaries are a classic privilege-escalation target — audit them with `find / -perm -4000`.

#### ACLs (Access Control Lists)

Standard permissions only express **one** user, **one** group, and everyone else. When you need "user bob can read this *and* group audit can read it too, but nobody else," use **ACLs**:

```bash
getfacl report.txt                  # view ACLs
setfacl -m u:bob:r report.txt       # grant bob read
setfacl -m g:audit:rw report.txt    # grant group audit read+write
setfacl -x u:bob report.txt         # remove bob's entry
```

A `+` at the end of `ls -l` permissions (`-rw-r--r--+`) means extra ACLs exist beyond what the basic bits show.

#### File attributes

Attributes are a layer *beneath* permissions, enforced by the filesystem itself — even root obeys them until they're removed:

```bash
lsattr file.txt           # list attributes
sudo chattr +i file.txt   # IMMUTABLE: nobody can modify/delete/rename it
sudo chattr -i file.txt   # remove immutability
sudo chattr +a app.log    # APPEND-ONLY: can add but not overwrite (great for logs)
```

`chattr +i` on a critical config is a cheap way to prevent accidental (or scripted) changes.

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
sudo useradd -m -s /bin/bash alice
sudo useradd -m -s /bin/bash bob
sudo usermod -aG webdev alice
sudo usermod -aG webdev bob

id alice
id bob
```

### Step 3 — Permissions in practice

```bash
cd ~ && mkdir -p permlab && cd permlab

cat > deploy.sh << 'EOF'
#!/bin/bash
echo "Deploying..."
EOF

ls -l deploy.sh          # no execute bit yet
./deploy.sh              # Permission denied

chmod +x deploy.sh
./deploy.sh              # works now

chmod 600 deploy.sh      # lock to owner only
ls -l deploy.sh

# Translate: what is 640 in rwx? Verify:
chmod 640 deploy.sh
ls -l deploy.sh          # -rw-r-----
```

### Step 4 — Ownership and a shared directory

```bash
sudo mkdir -p /srv/webdev
sudo chown root:webdev /srv/webdev
sudo chmod 2775 /srv/webdev      # rwxrwsr-x → setgid

ls -ld /srv/webdev               # note the 's' in group perms

# Files created here inherit the webdev group
sudo -u alice bash -c 'touch /srv/webdev/from-alice.txt'
ls -l /srv/webdev                # group is webdev, not alice
```

### Step 5 — Special bits in the wild

```bash
ls -l /usr/bin/passwd            # setuid root
ls -ld /tmp                      # sticky bit (t)
find /usr/bin -perm -4000 2>/dev/null   # all setuid binaries
```

### Step 6 — ACLs

```bash
cd ~/permlab
echo "quarterly numbers" > report.txt
chmod 640 report.txt

# Give bob read access WITHOUT changing owner/group/other
sudo setfacl -m u:bob:r report.txt
getfacl report.txt
ls -l report.txt                 # note the trailing '+'

sudo -u bob cat report.txt       # bob can read it now
```

### Step 7 — File attributes

```bash
echo "do not change" | sudo tee important.conf
sudo chattr +i important.conf
lsattr important.conf

sudo rm -f important.conf        # fails — even with sudo!
echo "x" | sudo tee -a important.conf   # fails too

sudo chattr -i important.conf    # remove the lock
sudo rm -f important.conf        # now it works
```

---

## Assignment

In `my-progress/day-04.md`:

1. **Reading perms:** A file shows `-rw-r-----`. Give the numeric form, and say exactly who can read it, who can write it, and who is locked out. Then explain in one line why `usermod -aG` is safer than `usermod -G`.
2. **Design a shared dropbox:** Create a directory two users can both add files to, where each user can delete **only their own** files (not each other's). Choose the right combination of ownership, group, and special bits (setgid + sticky), then prove it works by having a second user try to delete the first user's file. Show your commands and the result.

```bash
git add my-progress/day-04.md
git commit -m "day-04: users, groups, permissions, ACLs, attributes"
git push origin main
```

---

## Further Reading

- `man chmod`, `man chown`, `man usermod`, `man setfacl`, `man chattr`
- [chmod-calculator.com](https://chmod-calculator.com/) — visualize numeric ↔ symbolic
- [Understanding /etc/passwd](https://www.cyberciti.biz/faq/understanding-etcpasswd-file-format/)
- [ArchWiki: File permissions and attributes](https://wiki.archlinux.org/title/File_permissions_and_attributes)
