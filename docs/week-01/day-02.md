# Day 02 · The Filesystem — Navigation, Files & Text

## Learning Objectives

- Know where Linux came from and read the filesystem hierarchy like a map
- Move around the filesystem confidently and find files
- Create, copy, move, and remove files and directories
- Read and transform text with the everyday command-line tools

---

## Theory · ~15 min

### A short history (the 60-second version)

- **Unix (1970s)** — built at AT&T Bell Labs. It gave us the hierarchical filesystem and small composable tools joined by pipes. Powerful, but proprietary.
- **GNU (1983)** — Richard Stallman started the **GNU Project** to build a *free* Unix-compatible system, including tools you use daily (`bash`, `ls`, `grep`, `gcc`). It was missing a kernel.
- **Linux (1991)** — **Linus Torvalds** wrote a free Unix-like **kernel**. GNU tools + the Linux kernel = a complete, free operating system (why purists say **"GNU/Linux"**).

Linux is released under the **GPL** (an open source license), developed in the open by a global community. Nearly every production server runs Linux — as a DevOps engineer, the terminal is your home.

!!! note "Kernel vs. distribution"
    **Linux is the kernel** — the core that talks to hardware and manages processes. A **distribution** (Ubuntu, Debian, Alpine) bundles that kernel with GNU tools and a package manager to make a usable OS.

### The filesystem hierarchy

Unlike Windows (`C:\`, `D:\`), Linux has a **single tree** starting at the root, `/`. Everything hangs off it. The layout follows the **Filesystem Hierarchy Standard (FHS)**, so any Linux box is familiar: configs in `/etc`, logs in `/var/log`.

```
/
├── bin/    → essential user commands (ls, cp, cat)
├── etc/    → system-wide configuration files
├── home/   → regular users' home directories (/home/vagrant)
├── root/   → the root user's home directory
├── var/    → variable data: logs, caches, databases
├── tmp/    → temporary files, wiped on reboot
├── usr/    → user-installed programs, libraries, docs
├── opt/    → optional / third-party software
├── boot/   → kernel and bootloader files
├── dev/    → device files (disks, terminals, /dev/null)
├── proc/   → virtual: live kernel & process info
└── mnt/, media/ → mount points for other filesystems
```

The two you'll open most: **`/etc`** (a service's config) and **`/var/log`** (its logs) answer 90% of "why isn't this working?"

---

## Lab · ~50 min

Do everything below **inside your Vagrant VM** from Day 01 (`vagrant ssh`).

### Step 1 — Navigate the filesystem

```bash
pwd                      # where am I? (print working directory)
cd /                     # go to the root
ls                       # list the top-level FHS directories
ls -l                    # long form: permissions, owner, size, date
ls -la                   # also show hidden (dot) files
cd /var/log && pwd       # jump somewhere and confirm
cd                       # bare cd → back to your home directory
cd -                     # toggle back to the previous directory
```

`.` means "here", `..` means "one level up", `~` means "my home":

```bash
cd ~            # home
cd ..           # up one
cd ../../etc    # relative path hopping
```

### Step 2 — Look around and find things

```bash
cd /etc
ls -d */                     # only the sub-directories
cat os-release               # dump a small file (which distro is this?)
less services                # page through a big file (q to quit)

# Find files by name or type
find /etc -name "*.conf" 2>/dev/null | head   # config files under /etc
which ls                                       # where does a command live?
tree -L 1 /                                     # visualize the tree, 1 level deep
```

If `tree` is missing: `sudo apt update && sudo apt install -y tree`.

### Step 3 — Create files and directories

```bash
cd ~ && mkdir -p lab/day02 && cd lab/day02

touch notes.txt              # create an empty file
mkdir -p project/src project/docs   # -p makes parent dirs as needed
ls -R                        # recursive listing of what you built

echo "hello devops" > notes.txt      # write (overwrite)
echo "second line" >> notes.txt      # append
cat notes.txt
```

### Step 4 — Copy, move, rename, remove

```bash
cp notes.txt notes.bak               # copy
mv notes.bak project/docs/           # move into a directory
mv notes.txt readme.txt              # rename (mv = move/rename)
cp -r project project-copy           # -r to copy a directory tree

rm readme.txt                        # remove a file
rm -r project-copy                   # remove a directory tree
ls -R
```

!!! warning "`rm` is forever"
    There is no recycle bin. `rm -rf` on the wrong path is how people ruin their day. Double-check before you press Enter — especially with `*` or `sudo`.

### Step 5 — Redirection and pipes

Commands send output to the screen by default. You can redirect it to a file, or **pipe** it into another command:

```bash
ls /etc > etc-listing.txt        # save output to a file (overwrite)
ls /etc >> etc-listing.txt       # append instead
ls /nope 2>errors.txt            # send errors (stream 2) to a file
ls /etc | wc -l                  # pipe: count how many entries /etc has
```

A **pipe** (`|`) feeds one command's output into the next. This composition is the heart of the command line.

### Step 6 — Text tools: grep, cut, sort, uniq

Real admin work is reading and filtering text. `/etc/passwd` (one line per account) is a great sandbox:

```bash
wc -l /etc/passwd                    # how many accounts?
grep bash /etc/passwd                # lines containing "bash"
grep -v nologin /etc/passwd          # INVERT: lines NOT containing nologin
cut -d: -f1 /etc/passwd              # field 1 (delimiter ":") → usernames
cut -d: -f1,7 /etc/passwd            # username + login shell

# Which shells are in use, most common first?
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```

| Tool | One-line purpose |
|---|---|
| `grep` | Find lines matching a pattern (`-i` ignore case, `-v` invert, `-r` recursive) |
| `cut` | Slice out fields by delimiter |
| `sort` | Sort lines (`-r` reverse, `-n` numeric) |
| `uniq` | Collapse/count adjacent duplicates (sort first!) |
| `wc` | Count lines/words/bytes (`-l` lines) |
| `head` / `tail` | First / last N lines (`tail -f` follows live) |

### Step 7 — Edit streams with sed & awk

`sed` changes text; `awk` works with columns/fields:

```bash
# Build a tiny sample log
cat > access.log << 'EOF'
10.0.0.1 GET /home 200
10.0.0.2 GET /login 200
10.0.0.1 POST /login 401
10.0.0.3 GET /home 500
EOF

sed 's/GET/FETCH/g' access.log       # find & replace in the stream
awk '{print $1}' access.log          # first field of every line
awk '$4 >= 400 {print $2, $4}' access.log   # only error responses (status ≥ 400)
awk '{print $1}' access.log | sort | uniq -c   # requests per IP
```

!!! tip "grep finds, sed changes, awk computes"
    A rough rule: **grep** to *find* lines, **sed** to *change* lines, **awk** when you care about *fields/columns or math*. Most one-liners chain two or three with pipes.

---

## Assignment

In `my-progress/day-02.md`:

1. **Watch — the history of GNU & open source:** Watch [this video on the history of GNU and open source software](https://www.youtube.com/watch?v=sQDvkd2wtxU). In 3–4 sentences, tie together Unix, GNU, and Linux, and explain what the GPL's *copyleft* rule requires. Why does copyleft matter for a project the size of Linux?
2. **Research a directory:** Run `man hier` and pick **three** top-level directories you did *not* open during the lab (e.g. `/srv`, `/run`, `/boot`, `/opt`, `/mnt`). For each, write one line on its purpose and note whether it currently exists on your VM.
3. **Hands-on — build a one-liner pipeline:** Using **only** commands from today, write a **single pipeline** (chained with `|`) that answers a real question about your system. For example: *the top 3 most common login shells on this machine*, or *how many `.conf` files live under `/etc`*. Run it, paste the command and its output, and explain each stage of the pipe in one line.

---

## Further Reading

- [The Filesystem Hierarchy Standard (FHS 3.0)](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html) — the actual spec
- `man hier` — the filesystem hierarchy, right on your machine
- [Linus Torvalds' original 1991 announcement](https://groups.google.com/g/comp.os.minix/c/dlNtH7RRrGA/m/SwRavCzVE7gJ) — the "just a hobby" email
- [regexr.com](https://regexr.com/) — build and test regular expressions interactively
