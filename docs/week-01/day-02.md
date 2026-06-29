# Day 02 · Linux Basics I — Filesystem & Core Commands

## Learning Objectives

- Navigate the Linux filesystem confidently
- Use core commands to create, move, copy, and delete files
- Read and filter file content from the terminal

---

## Theory · ~20 min

### Why Linux?

Nearly every server in production runs Linux. AWS EC2, Google Cloud, DigitalOcean — they all default to Linux. As a DevOps engineer, you will spend most of your time in a Linux terminal. Getting comfortable here is non-negotiable.

### The Linux Filesystem Tree

Unlike Windows (C:\, D:\), Linux has a single root `/` and everything branches from it:

```
/
├── bin/      → essential binaries (ls, cp, mv)
├── etc/      → configuration files (nginx.conf, sshd_config)
├── home/     → user home directories (/home/balman)
├── var/      → variable data: logs (/var/log), databases
├── tmp/      → temporary files, cleared on reboot
├── usr/      → user-installed programs and libraries
├── proc/     → virtual filesystem: live kernel/process info
├── root/     → home directory for root user
└── dev/      → device files (disks, terminals)
```

!!! tip
    `/etc` is where almost all service configuration lives. When something doesn't work, `/etc` and `/var/log` are the first two places you look.

### Everything is a file

In Linux, almost everything is represented as a file — including hardware devices, network sockets, and running processes. This is why the same tools work on text, configs, logs, and even disk devices.

### Core Command Structure

```
command  [options]  [arguments]
  ls       -la       /var/log
```

- **Options** modify behavior (`-l` for long format, `-a` for hidden files)
- **Arguments** are what the command acts on (a file, a directory)

---

## Lab · ~50 min

### Step 1 — Navigate the filesystem

```bash
pwd               # print working directory
ls                # list files
ls -la            # long format, show hidden files
cd /              # go to root
ls                # see the top-level directories
cd ~              # go to your home directory
cd /var/log       # go to logs directory
ls -lh            # list with human-readable sizes
```

### Step 2 — Create, copy, move, delete

```bash
mkdir ~/devops-practice
cd ~/devops-practice

# Create files
touch file1.txt file2.txt
echo "Hello DevOps" > hello.txt
cat hello.txt

# Copy
cp hello.txt hello-backup.txt
ls -la

# Move / rename
mv hello-backup.txt hello-copy.txt
ls

# Create nested directories
mkdir -p projects/week-01/lab
ls -R projects/

# Delete
rm hello-copy.txt
rm -rf projects/    # careful: -rf deletes recursively without asking
ls
```

!!! warning
    `rm -rf` has no undo. There is no Recycle Bin. Think before you run it.

### Step 3 — Read and search file contents

```bash
# View full file
cat /etc/os-release

# Page through large files
less /var/log/syslog     # press q to quit, / to search

# First and last lines
head -5 /var/log/syslog
tail -10 /var/log/syslog
tail -f /var/log/syslog  # live follow (Ctrl+C to stop)

# Search inside files
grep "error" /var/log/syslog
grep -i "error" /var/log/syslog   # case insensitive
grep -n "error" /var/log/syslog   # show line numbers
```

### Step 4 — Find files

```bash
# Find by name
find /etc -name "*.conf"

# Find by type (f=file, d=directory)
find /var/log -type f -name "*.log"

# Find recently modified files
find ~ -type f -mtime -1    # modified in last 1 day
```

### Step 5 — Pipelines

The `|` (pipe) takes the output of one command and feeds it into the next:

```bash
# Count lines in a file
cat /etc/passwd | wc -l

# List only .log files
ls /var/log | grep ".log"

# Find the 5 largest files in /var
du -sh /var/* 2>/dev/null | sort -rh | head -5
```

---

## Assignment

In `my-progress/day-02.md`:

1. What is the full path to the configuration directory for SSH on your system? What files are in it?
2. How many lines are in `/etc/passwd`? What does each line represent?
3. Find all `.conf` files under `/etc` that contain the word `server`. List the file paths.
4. Write a one-liner that counts how many running processes exist on your machine right now (hint: `ps aux | wc -l`).

Push your answers:
```bash
git add my-progress/day-02.md
git commit -m "day-02: linux basics I complete"
git push origin main
```

---

## Further Reading

- `man ls`, `man find`, `man grep` — the built-in manual pages are the best reference
- [Linux Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
- [explainshell.com](https://explainshell.com) — paste any command and see each part explained
