# Day 03 · Linux Basics II — Users, Permissions & Processes

## Learning Objectives

- Understand Linux user and group model
- Read and modify file permissions
- List, monitor, and kill processes

---

## Theory · ~20 min

### Users and Groups

Linux is a multi-user system. Every file and process belongs to a user and a group.

```bash
whoami          # your current username
id              # your user ID (UID), group ID (GID), and all groups
cat /etc/passwd # all users on the system
```

Each line in `/etc/passwd` has 7 fields:
```
username : password : UID : GID : comment : home_dir : shell
balman   :    x     : 1000:  1000:         :/home/balman:/bin/bash
```

The `x` in the password field means the actual password hash is in `/etc/shadow` (readable only by root).

**Root** (UID 0) is the superuser — it can do anything on the system. You escalate to root using `sudo`.

### File Permissions

Every file has three permission sets: **owner**, **group**, **others**.

```
-rwxr-xr--  1  balman  devops  1234  Jun 01  script.sh
 ↑↑↑↑↑↑↑↑↑
 │└──┘└──┘└──┘
 │ owner group others
 └── file type (- = file, d = directory, l = symlink)
```

Each set has three bits:

| Symbol | Meaning | Numeric |
|---|---|---|
| `r` | read | 4 |
| `w` | write | 2 |
| `x` | execute | 1 |
| `-` | no permission | 0 |

So `rwxr-xr--` = `754`

```bash
chmod 755 script.sh    # rwxr-xr-x
chmod 644 config.txt   # rw-r--r--
chmod +x script.sh     # add execute for all
chown balman:devops file.txt  # change owner and group
```

### Processes

Every running program is a process with a unique **PID** (process ID).

```bash
ps aux            # all processes, all users
ps aux | grep nginx
top               # live process monitor (q to quit)
htop              # improved top (may need to install)
```

Process states: `R` running, `S` sleeping, `Z` zombie (parent didn't clean up), `T` stopped.

```bash
kill <PID>        # send SIGTERM (polite stop)
kill -9 <PID>     # send SIGKILL (immediate stop, no cleanup)
killall nginx     # kill by name
```

---

## Lab · ~50 min

### Step 1 — Explore users and groups

```bash
whoami
id
cat /etc/passwd | grep -v "nologin\|false"   # real user accounts
cat /etc/group | grep sudo                    # who has sudo access
last                                          # login history
```

### Step 2 — Create a user and group

```bash
sudo groupadd devops-team
sudo useradd -m -s /bin/bash -G devops-team student01
sudo passwd student01        # set a password

id student01                 # verify
ls -la /home/                # new home dir created
```

### Step 3 — File permissions in practice

```bash
cd ~/devops-practice

# Create a script
cat > deploy.sh << 'EOF'
#!/bin/bash
echo "Deploying application..."
EOF

ls -la deploy.sh      # what are the permissions?

# Try running it
./deploy.sh           # likely: Permission denied

# Add execute permission
chmod +x deploy.sh
./deploy.sh           # now it works

# Make it private (only owner can read/write/execute)
chmod 700 deploy.sh
ls -la deploy.sh

# Make a file world-readable but not writable
chmod 644 deploy.sh
ls -la deploy.sh
```

### Step 4 — Understand sudo

```bash
# Try something that requires root
cat /etc/shadow               # should fail
sudo cat /etc/shadow          # works if you're in sudoers

# Run a command as another user
sudo -u student01 whoami

# Open a root shell (use carefully, exit when done)
sudo -i
whoami                        # should say root
exit
```

### Step 5 — Work with processes

```bash
# Start a background process
sleep 300 &       # the & runs it in background
ps aux | grep sleep

# Get its PID
PID=$(pgrep sleep)
echo "Sleep PID is: $PID"

# Monitor it
top -p $PID       # watch just this process (q to quit)

# Kill it
kill $PID
ps aux | grep sleep   # should be gone

# See system resource usage
free -h
df -h
uptime            # how long the system has been running + load average
```

---

## Assignment

In `my-progress/day-03.md`:

1. What is the difference between `kill` and `kill -9`? When would you use each?
2. A file has permissions `640`. Who can read it? Who can write it? Who cannot access it at all?
3. Create a file called `secret.txt` and set permissions so that only the owner can read or write it. Paste the `ls -la` output.
4. How many processes are currently running as your user? (use `ps aux | grep <your-username> | wc -l`)

```bash
git add my-progress/day-03.md
git commit -m "day-03: users, permissions, processes"
git push origin main
```

---

## Further Reading

- `man chmod`, `man useradd`, `man ps`
- [Linux permissions explained visually](https://chmod-calculator.com/)
- [Understanding /etc/passwd](https://www.cyberciti.biz/faq/understanding-etcpasswd-file-format/)
