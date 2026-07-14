# Day 3 · Process & Disk Management

## Learning Objectives

- See what is running on a machine and understand what a process is
- Find, inspect, and stop processes by PID and by name
- Check memory and CPU load at a glance
- Report disk and filesystem usage and find what is eating space

---

## Theory · ~15 min

### What is a process?

A **process** is a running program. Every time you launch something — a shell, `nginx`, a Python script — the kernel creates a process and gives it a unique number, the **PID** (Process ID). Processes form a tree: each is started by a **parent** (its **PPID**), all the way back to **PID 1** (`systemd`), the first process the kernel starts at boot.

As a DevOps engineer, "is it running? why is it slow? what's eating the box?" are daily questions — and the answers come from a handful of process and disk commands.

### Signals — how you talk to a process

You don't "close" a process; you send it a **signal**. The common ones:

| Signal | Number | Meaning |
|---|---|---|
| `SIGTERM` | 15 | Politely ask it to stop and clean up (the **default**) |
| `SIGKILL` | 9 | Force-kill immediately — cannot be ignored (last resort) |
| `SIGHUP` | 1 | Hang up — often used to tell a service to reload its config |

Always try `SIGTERM` first; reach for `SIGKILL` (`-9`) only when something is truly stuck.

### Disks, partitions, and filesystems

- A **disk** (e.g. `/dev/sda`) is the physical/virtual device.
- It's split into **partitions** (`/dev/sda1`).
- A partition is formatted with a **filesystem** (ext4, xfs) and **mounted** onto a directory (the *mount point*, e.g. `/`).

"The disk is full" almost always means *one mounted filesystem* is full — so you check per-filesystem usage, then hunt down the big directories.

---

## Lab · ~50 min

Work **inside your Vagrant VM** (`vagrant ssh`).

### Step 1 — Who am I, what's the uptime

```bash
uptime               # how long the box has been up + load average
uname -a             # kernel and architecture
date                 # current date/time
```

The **load average** (three numbers) is the average number of processes waiting to run over the last 1, 5, and 15 minutes. Roughly, compare it to your CPU count.

### Step 2 — List running processes

```bash
ps aux | head            # every process: USER, PID, %CPU, %MEM, COMMAND
ps aux | wc -l           # how many processes are running

# Find a specific process
ps aux | grep sshd       # the SSH daemon
pgrep -a bash            # PIDs (and command) of all bash processes
```

Reading a `ps aux` row: the **2nd column is the PID**, the columns after are CPU%, MEM%, and (at the end) the command.

### Step 3 — Watch processes live

```bash
top                  # live, sorted view (press 'q' to quit)
                     # inside top: 'M' sorts by memory, 'P' by CPU
```

If available, `htop` is a friendlier, colorful version:

```bash
sudo apt install -y htop
htop                 # arrow keys to scroll, F10 or q to quit
```

### Step 4 — Memory and CPU at a glance

```bash
free -h              # memory used/free, human-readable
nproc                # how many CPU cores
cat /proc/loadavg    # the raw load-average numbers
```

### Step 5 — Start, background, and stop a process

```bash
# Start a long-running process in the background
sleep 300 &          # '&' runs it in the background; note the [1] PID printed
jobs                 # list background jobs of this shell
ps aux | grep sleep  # find its PID

# Stop it politely, then confirm
kill <PID>           # sends SIGTERM (15) by default
ps aux | grep sleep  # gone?

# Force-kill by name if something is stuck
sleep 300 &
pkill sleep          # kill by process name
killall sleep        # same idea; kills all matching by name
```

Try the difference between a graceful stop and a force-kill:

```bash
sleep 500 &
kill -15 %1          # %1 = job number 1 → graceful
sleep 500 &
kill -9 $!           # $! = PID of the most recent background job → forced
```

### Step 6 — Disk and filesystem usage

```bash
df -h                # usage per MOUNTED filesystem, human-readable
df -h /              # just the root filesystem
lsblk                # tree of disks and partitions
```

`df` answers "which filesystem is full?" Look at the **Use%** column.

### Step 7 — Find what's eating space

```bash
cd /var
sudo du -sh *             # size of each item in /var, summarized
sudo du -sh * | sort -rh | head   # biggest first (top offenders)

du -sh ~                  # total size of your home directory
```

`df` tells you a filesystem is full; `du` finds *which directory* is to blame. Learn this pair — it's the classic "disk full at 2am" workflow.

---

## Assignment

1. **Hands-on — investigate and control a process:** In one terminal, start a background process you can identify (e.g. `sleep 600 &` or `yes > /dev/null &`). Then, using the commands from today:
   - Find its **PID** two different ways (e.g. `ps aux | grep` and `pgrep`).
   - Show its **CPU and memory** usage from `top` (or `ps`).
   - Stop it with a **graceful** `SIGTERM`, confirm it's gone, then start it again and stop it with a **forced** `SIGKILL (-9)`.

   Paste your commands and outputs, and explain in one line *when* you would actually need `-9` instead of the default.

   *Stretch:* run `df -h`, identify the filesystem with the highest **Use%**, then use `du -sh * | sort -rh` to find the single largest directory inside it.

---

## Further Reading

- `man ps`, `man kill`, `man df`, `man du`
- [Understanding Linux load average](https://www.brendangregg.com/blog/2017-08-08/linux-load-averages.html)
- [The `/proc` filesystem explained](https://www.kernel.org/doc/html/latest/filesystems/proc.html)
