# Day 02 · Linux History & the Filesystem Hierarchy

## Learning Objectives

- Understand where Linux came from and why it matters for DevOps
- Explain what "open source" means and why Linux is licensed the way it is
- Read the Linux filesystem hierarchy and know what each top-level directory is for
- Locate configuration, logs, and binaries by knowing where they *should* live

---

## Theory · ~25 min

### A short history of Linux

To understand Linux, you have to start with **Unix**.

- **1969–1970s — Unix.** Built at AT&T Bell Labs by Ken Thompson and Dennis Ritchie. It introduced ideas we still rely on every day: a hierarchical filesystem, "everything is a file," small composable tools joined by pipes, and a multi-user design. Unix was powerful but proprietary and expensive.
- **1983 — GNU.** Richard Stallman launched the **GNU Project** ("GNU's Not Unix") to build a completely *free* Unix-compatible operating system. By the late 1980s GNU had most of the pieces — a compiler (`gcc`), a shell (`bash`), core utilities (`ls`, `cp`, `grep`) — but it was missing one critical component: a working **kernel**.
- **1991 — the Linux kernel.** A Finnish student named **Linus Torvalds** wrote a Unix-like kernel as a hobby project and posted it online. His now-famous message: *"I'm doing a (free) operating system (just a hobby, won't be big and professional...)."* He was wrong about the "won't be big" part.
- **GNU + Linux.** Torvalds' kernel plus the GNU userland tools formed a complete, free operating system. This is why purists call it **"GNU/Linux"** — the kernel is *Linux*, but most of the commands you type every day come from GNU.

!!! note "Kernel vs. Operating System"
    Strictly speaking, **Linux is the kernel** — the core that talks to hardware, manages memory, schedules processes, and handles the filesystem. A **distribution** (Ubuntu, Debian, Red Hat, Alpine) bundles that kernel with GNU tools, a package manager, and default configuration to make a usable OS.

### Linux as an open source project

Linux is released under the **GNU General Public License (GPL v2)**. This is what "open source" means in practice:

| Freedom | What it means for you |
|---|---|
| **Use** | Run it for any purpose, on any number of machines, for free |
| **Study** | Read the actual source code to see exactly how it works |
| **Modify** | Change it to fit your needs |
| **Share** | Redistribute the original or your modified version |

The GPL adds one crucial rule — **copyleft**: if you distribute a modified version, you must release your changes under the same license. This prevents anyone from taking Linux private, and it's a big reason the ecosystem stayed healthy and collaborative.

Linux is developed in the open by a global community — thousands of contributors, from hobbyists to engineers at Intel, Google, Red Hat, and IBM, all submitting patches to a shared codebase. Torvalds still oversees the kernel, and he created **Git** in 2005 specifically to manage its development (you'll use Git on Day 07).

!!! tip "Why this matters for DevOps"
    Nearly every server in production runs Linux — AWS, Google Cloud, Azure, and DigitalOcean all default to it. It's free, scriptable, stable, and transparent. As a DevOps engineer you'll live in a Linux terminal, so understanding *why* it's built the way it is makes the "how" much easier to reason about.

### The Linux filesystem hierarchy

Unlike Windows, which has multiple drive letters (`C:\`, `D:\`), Linux has a **single tree** that starts at the root, written `/`. Everything — every disk, device, and file — hangs off that one root.

The layout isn't random. It follows the **Filesystem Hierarchy Standard (FHS)**, a specification that defines what belongs where. Because distributions follow the FHS, you can sit down at an unfamiliar server and still know that configs are in `/etc` and logs are in `/var/log`.

```
/
├── bin/    → essential user commands (ls, cp, cat)
├── sbin/   → essential system/admin commands (fdisk, ip, reboot)
├── etc/    → system-wide configuration files
├── home/   → regular users' home directories (/home/vagrant)
├── root/   → the root user's home directory (NOT the same as /)
├── var/    → variable data: logs, caches, spool, databases
├── tmp/    → temporary files, wiped on reboot
├── usr/    → user-installed programs, libraries, docs
├── opt/    → optional / third-party software packages
├── lib/    → shared libraries needed by binaries in /bin and /sbin
├── boot/   → kernel and bootloader files
├── dev/    → device files (disks, terminals, null)
├── proc/   → virtual filesystem: live kernel & process info
├── sys/    → virtual filesystem: hardware & kernel settings
├── mnt/    → temporary mount point for filesystems
└── media/  → auto-mounted removable media (USB, CD)
```

### Important directories and their use cases

These are the ones you'll actually touch as a DevOps engineer:

| Directory | What lives here | When you'll use it |
|---|---|---|
| `/etc` | System & service configuration (`sshd_config`, `nginx/`, `fstab`) | Configuring services, changing SSH/network settings |
| `/var/log` | Log files from the system and services | Debugging — *always* the first place to look when something breaks |
| `/home` | Per-user home directories, dotfiles, SSH keys | Day-to-day work, storing scripts, `~/.ssh/` keys |
| `/usr/bin`, `/usr/local/bin` | Installed program binaries | Finding where a command lives (`which nginx`) |
| `/tmp` | Scratch space, cleared on reboot | Temporary files in scripts — never store anything important |
| `/proc` | Live view of the running kernel & processes | Inspecting a process (`/proc/<pid>/`), checking `cpuinfo` / `meminfo` |
| `/dev` | Device files, including `/dev/null` and disks | Redirecting output to `/dev/null`, referencing disks |
| `/opt` | Self-contained third-party apps | Where some vendor software installs itself |

!!! tip "The two directories you'll open most"
    When a service misbehaves, `/etc` (its config) and `/var/log` (its logs) answer 90% of "why isn't this working?" questions. Build the habit now.

!!! note "Everything is a file"
    A Unix idea Linux inherited: hardware devices, running processes, and kernel settings are all exposed *as files*. That's why `/dev`, `/proc`, and `/sys` exist — you can read a process's memory usage or a disk's info with the same tools you use on a text file. It's what makes Linux so scriptable.

---

## Lab · ~45 min

Do everything below **inside your Vagrant VM** from Day 01 (`vagrant ssh`).

### Step 1 — Stand at the root and look around

```bash
cd /
ls -l                 # every top-level FHS directory, one per line
ls -l / | wc -l       # roughly how many top-level entries exist
```

Compare what you see against the tree in the theory section. Every distro follows the same shape.

### Step 2 — Explore configuration in /etc

```bash
cd /etc
ls | head -30                 # a sample of what's configured on this box
ls -d */                      # config directories (nginx/, ssh/, apt/ ...)

# Look at real config files
cat /etc/os-release           # which distro & version is this?
cat /etc/hostname             # the machine's name
less /etc/ssh/sshd_config     # the SSH server config (q to quit)
```

Notice these are all plain text — Linux config is human-readable and editable.

### Step 3 — Read the logs in /var/log

```bash
cd /var/log
ls -lh                        # log files with human-readable sizes

# The main system journal
sudo tail -20 /var/log/syslog # last 20 lines
sudo tail -f /var/log/syslog  # live-follow (Ctrl+C to stop)

# Authentication events (logins, sudo usage)
sudo tail -20 /var/log/auth.log
```

### Step 4 — See "everything is a file" in action

```bash
# /proc — live process and kernel info, generated on the fly
cat /proc/cpuinfo | head -20   # your CPU
cat /proc/meminfo | head -5    # your memory
cat /proc/uptime               # seconds since boot

# Each running process has a directory under /proc
ls /proc/1/                    # PID 1 = the init process (systemd)

# /dev — device files
ls -l /dev/null                # the "black hole" — discards anything written to it
echo "this disappears" > /dev/null
```

### Step 5 — Find where commands actually live

```bash
which ls                       # a core GNU utility
which vagrant 2>/dev/null      # (nothing — vagrant is on your host, not the VM)
type cd                        # some commands are shell built-ins, not files

# Confirm the binaries sit in the FHS-defined locations
ls -l /bin/ls /usr/bin/grep
```

### Step 6 — Map the tree yourself

```bash
# Install tree if it's not there, then view 1 level deep
sudo apt update && sudo apt install -y tree
tree -L 1 /
tree -L 1 /var
```

---

## Assignment

In `my-progress/day-02.md`:

1. **History & open source:** In 3–4 sentences, tie together Unix, GNU, and Linux, and explain what the GPL's *copyleft* rule requires. Why does copyleft matter for a project the size of Linux?
2. **Research a directory:** Run `man hier` and pick **three** top-level directories you did *not* open during the lab (e.g. `/srv`, `/run`, `/boot`, `/opt`, `/mnt`). For each, write one line on its purpose and note whether it currently exists on your VM.

Push your answers:

```bash
git add my-progress/day-02.md
git commit -m "day-02: linux history and filesystem hierarchy"
git push origin main
```

---

## Further Reading

- [The Filesystem Hierarchy Standard (FHS 3.0)](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html) — the actual spec
- [Linus Torvalds' original 1991 announcement](https://groups.google.com/g/comp.os.minix/c/dlNtH7RRrGA/m/SwRavCzVE7gJ) — the "just a hobby" email
- [GNU: What is Free Software?](https://www.gnu.org/philosophy/free-sw.html)
- `man hier` — the manual page describing the filesystem hierarchy, right on your machine
