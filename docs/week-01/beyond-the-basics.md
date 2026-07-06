# Beyond the Basics

!!! info "Not taught — a map, not a lesson"
    This page is **not part of the daily curriculum**. Week 1 gives you a working foundation in Linux system administration; it can't cover everything. This is a curated map of the topics, config files, and commands that a professional Linux/DevOps engineer runs into — so you know they exist and where to dig deeper when you need them.

---

## Topics we didn't cover

These are the "next layer down" of how Linux really works. You don't need them to start, but they come up constantly in containers, security, and production debugging.

| Topic | What it is | Why it matters |
|---|---|---|
| **systemd** | The init system that boots the machine and supervises services (PID 1). Unit files, targets, `journalctl`, and **timers** (a modern cron alternative). | Every service you deploy is a systemd unit. Understanding it is core to running apps in production. |
| **Cgroups (control groups)** | Kernel feature that limits and accounts for a process group's CPU, memory, and I/O. | The "limits" half of how containers work. `docker run -m 512m` is cgroups underneath. |
| **Namespaces** | Kernel feature that isolates what a process can *see* — its own PIDs, network, mounts, hostname, users. | The "isolation" half of containers. A container is mostly just namespaces + cgroups. |
| **Capabilities** | Splits root's power into ~40 fine-grained privileges (e.g. `CAP_NET_BIND_SERVICE` to bind port 80) that can be granted individually. | Lets you drop most of root's power from a service — least privilege in practice. |
| **Linux Security Modules (LSM)** | A kernel framework that hooks security policy into the kernel. Implementations: **SELinux**, **AppArmor**. | Confine a process so that even if compromised it can't touch files/ports outside its policy. |
| **Mandatory Access Control (MAC)** | Access rules enforced by system policy that users *cannot* override (unlike the standard "discretionary" `rwx`/ACLs from Day 4). | The model behind SELinux/AppArmor; common in hardened and regulated environments. |
| **Mount namespaces & filesystems** | `mount`, `/etc/fstab`, bind mounts, overlayfs, tmpfs. | How disks, network shares, and container layers get attached to the tree. |
| **Networking internals** | `iptables`/`nftables`, routing tables, network namespaces, `systemd-resolved`. | Firewalls, container networking, and "why can't this connect?" debugging. (Week 2 covers networking basics.) |
| **SSH deep-dive** | Key types, `~/.ssh/config`, agent forwarding, hardening `sshd_config`, bastions. | Your primary way onto every server. Worth mastering. |
| **Package internals** | How `.deb`/`.rpm` are built, repositories, GPG signing, pinning versions. | Reproducible, trusted software installs. |
| **Kernel & boot** | GRUB, initramfs, kernel modules (`lsmod`, `modprobe`), `/proc` & `/sys` tuning via `sysctl`. | Deep troubleshooting and performance tuning. |
| **Observability** | `strace`, `ltrace`, `perf`, `dmesg`, `/proc` internals. | When logs aren't enough, these show what a process is *actually* doing. |

---

## Important config files

Knowing *where* things are configured is half of system administration. These are the files you'll edit or read most often.

| File / directory | What it controls |
|---|---|
| `/etc/os-release` | Distro name and version |
| `/etc/hostname`, `/etc/hosts` | Machine name and static name→IP mappings |
| `/etc/passwd`, `/etc/shadow`, `/etc/group` | Users, password hashes, groups |
| `/etc/sudoers`, `/etc/sudoers.d/` | Who may run `sudo` and how (edit with `visudo`) |
| `/etc/ssh/sshd_config` | SSH **server** settings (ports, key auth, root login) |
| `~/.ssh/config`, `~/.ssh/authorized_keys` | SSH **client** shortcuts and which keys may log in |
| `/etc/fstab` | Filesystems mounted at boot |
| `/etc/crontab`, `/etc/cron.d/`, `/var/spool/cron/` | System and per-user scheduled jobs |
| `/etc/systemd/system/` | Your custom service unit files |
| `/etc/environment`, `/etc/profile`, `/etc/profile.d/` | System-wide environment and login setup |
| `~/.bashrc`, `~/.profile`, `~/.bash_profile` | Per-user shell config (Day 5) |
| `/etc/apt/sources.list`, `/etc/apt/sources.list.d/` | Where `apt` fetches packages |
| `/etc/resolv.conf` | DNS servers the system uses |
| `/etc/netplan/` | Network interface configuration (Ubuntu) |
| `/etc/logrotate.conf`, `/etc/logrotate.d/` | How logs are rotated and pruned |

---

## Important commands

A quick-reference index. If a command here is unfamiliar, that's a signal to run `man <command>` and experiment. Grouped by what you're trying to do.

### Files & navigation
`ls` · `cd` · `pwd` · `cp` · `mv` · `rm` · `mkdir` · `ln` · `find` · `tree` · `stat` · `file` · `du` · `df`

### Viewing & text processing
`cat` · `less` · `head` · `tail` · `grep` · `sed` · `awk` · `cut` · `tr` · `sort` · `uniq` · `wc` · `tee` · `diff` · `xargs`

### Users, groups & permissions
`whoami` · `id` · `who` · `su` · `sudo` · `useradd` · `usermod` · `userdel` · `groupadd` · `passwd` · `chmod` · `chown` · `chgrp` · `getfacl` · `setfacl` · `chattr` · `lsattr`

### Processes & resources
`ps` · `top` · `htop` · `kill` · `killall` · `pgrep` · `pkill` · `nice` · `free` · `uptime` · `vmstat` · `iostat` · `lsof`

### Services & scheduling
`systemctl` · `journalctl` · `service` · `crontab` · `at` · `systemd-analyze`

### Packages
`apt` · `apt-get` · `dpkg` · `snap` · (RHEL: `dnf` · `yum` · `rpm`)

### Networking
`ip` · `ping` · `ss` · `netstat` · `curl` · `wget` · `dig` · `nslookup` · `traceroute` · `nc` · `nmap` · `ssh` · `scp` · `rsync`

### Disks & filesystems
`mount` · `umount` · `lsblk` · `fdisk` · `mkfs` · `blkid` · `fsck`

### System info & help
`uname` · `hostname` · `uptime` · `date` · `lscpu` · `lsmod` · `dmesg` · `man` · `which` · `type` · `whereis` · `history` · `alias`

!!! tip "How to learn any command"
    1. `man <command>` — the authoritative reference (`/` to search inside it)
    2. `<command> --help` — a quick summary
    3. [explainshell.com](https://explainshell.com) — paste a whole command line and get each flag explained
    4. [tldr pages](https://tldr.sh/) — practical examples instead of exhaustive docs (`sudo apt install tldr`)

---

## Where to go next

- [Linux Journey](https://linuxjourney.com/) — free, structured, beginner→advanced
- [The Linux Command Line (free book)](https://linuxcommand.org/tlcl.php) by William Shotts
- [Julia Evans' zines & blog](https://jvns.ca/) — approachable deep-dives on Linux internals, `strace`, networking
- [Brendan Gregg's site](https://www.brendangregg.com/) — the reference for Linux performance and observability
- `man hier`, `man 7 signal`, `man 5 crontab` — excellent manual pages already on your machine
