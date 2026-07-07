# Day 05 · The Shell — Types, Profiles & Environment

## Learning Objectives

- Understand what a shell is and the difference between common shells
- Know how login vs. non-login and interactive vs. non-interactive shells load config, and in what order
- Work with environment variables and understand how they're inherited
- Read exit/status codes and chain commands based on them
- Create aliases and shell functions to speed up your daily work

---

## Theory · ~25 min

### What is a shell?

A **shell** is the program that reads the commands you type and asks the kernel to run them. It's your interface to the operating system. When you `vagrant ssh` into the VM and see a prompt, a shell is waiting for input.

The shell is both an **interactive command interpreter** and a **programming language** — the same `if`, `for`, and variables you type by hand also power scripts (Days 6–7).

### Shell types

| Shell | Notes |
|---|---|
| `sh` | The original Bourne shell. Minimal, POSIX baseline. Still the "lowest common denominator" for portable scripts. |
| `bash` | **B**ourne **A**gain **Sh**ell — the default on most Linux distros, including our Ubuntu VM. This is what we use. |
| `zsh` | Popular on macOS (default since Catalina). Bash-compatible with nicer completion and theming. |
| `fish` | Friendly, modern, but *not* POSIX-compatible — scripts written for bash won't run in it. |

```bash
echo $0            # which shell is running right now?
echo $SHELL        # your default login shell (from /etc/passwd)
cat /etc/shells    # shells installed on this system
```

!!! note "SHELL vs. \$0"
    `$SHELL` is your *configured default* shell — it doesn't change just because you launched another one. `$0` reflects the shell **actually running** the current session. Start `sh` from inside bash and `$0` changes while `$SHELL` does not.

### Login vs. non-login, interactive vs. non-interactive

How the shell starts decides **which config files it reads**. Four combinations matter:

- **Login shell** — started when you log in (SSH, console, `su -`). Loads your profile files.
- **Non-login shell** — a shell you open from within an existing session (a new terminal tab, running `bash`).
- **Interactive** — you type at a prompt.
- **Non-interactive** — running a script; no prompt.

### Profiles and their precedence

For **bash**, startup files are read in this order:

**Login shell** reads the first profile it finds, then your bashrc if that profile sources it:

```
/etc/profile                         ← system-wide, all users
   └─ /etc/profile.d/*.sh            ← drop-in scripts
~/.bash_profile   → ~/.bash_login → ~/.profile
   (only the FIRST one that exists is read)
```

**Interactive non-login shell** (new terminal tab) reads:

```
/etc/bash.bashrc                     ← system-wide
~/.bashrc                            ← your per-user interactive config
```

**Non-interactive shell** (a script) reads neither — it uses `$BASH_ENV` if set, otherwise nothing.

!!! tip "The practical rule"
    Put **environment variables and `PATH`** in `~/.profile` (or `~/.bash_profile`) so they're set once at login and inherited everywhere. Put **aliases, functions, and prompt tweaks** in `~/.bashrc` so every interactive shell gets them. Most `~/.bash_profile` files simply `source ~/.bashrc` to get both.

### Environment variables

Variables hold values the shell and programs read. A **shell variable** is local to the current shell; an **environment variable** is `export`ed so child processes inherit it.

```bash
name="balman"          # shell variable (not inherited)
export EDITOR="vim"    # environment variable (inherited by children)
echo "$name"
printenv EDITOR
env                    # list all environment variables
```

Common ones you'll meet constantly:

| Variable | Purpose |
|---|---|
| `PATH` | Colon-separated dirs the shell searches for commands |
| `HOME` | Your home directory (`~`) |
| `USER` | Your username |
| `PWD` | Current working directory |
| `SHELL` | Your default shell |
| `LANG` | Language/locale settings |

`PATH` is the one you'll edit most — it's why typing `ls` finds `/usr/bin/ls`:

```bash
echo "$PATH"
export PATH="$HOME/bin:$PATH"   # add your own bin dir, searched first
```

### Exit / status codes

Every command returns a numeric **exit code** when it finishes. `0` means success; anything else (1–255) means some kind of failure. Scripts and automation live or die by this.

```bash
ls /etc >/dev/null
echo $?          # 0  → success

ls /nope 2>/dev/null
echo $?          # 2  → failure ($? holds the LAST command's code)
```

Chain commands based on the result:

```bash
mkdir -p ~/lab && cd ~/lab       # run cd ONLY if mkdir succeeded
ping -c1 host || echo "unreachable"   # run echo ONLY if ping failed
```

!!! note "`$?` is a big deal"
    In CI/CD pipelines a non-zero exit code is how a step reports failure and stops the pipeline. Getting exit codes right is the difference between a broken deploy that halts loudly and one that silently ships bad code.

### Aliases and functions

An **alias** is a short name for a longer command. A **function** is a small named block that can take arguments and run multiple commands — more powerful than an alias.

```bash
# alias: simple text substitution
alias ll='ls -alh'
alias gs='git status'

# function: takes arguments, runs logic
mkcd() {
  mkdir -p "$1" && cd "$1"
}
mkcd ~/projects/newapp     # makes the dir AND enters it
```

Aliases and functions defined at the prompt vanish when the shell closes. Put them in `~/.bashrc` to keep them permanently.

---

## Lab · ~45 min

Work **inside your Vagrant VM** (`vagrant ssh`).

### Step 1 — Identify your shell and its config

```bash
echo $0
echo $SHELL
cat /etc/shells
ls -la ~ | grep -E '\.bash|\.profile'   # your startup files
```

### Step 2 — Watch precedence in action

```bash
# Add a marker to each file, then observe which loads
echo 'echo "[loaded ~/.profile]"' >> ~/.profile
echo 'echo "[loaded ~/.bashrc]"'  >> ~/.bashrc

# Login shell (reads profile)
bash -l -c 'echo done'

# Interactive non-login shell (reads .bashrc)
bash -i -c 'echo done'
```

Which marker printed in each case? That's precedence, live.

### Step 3 — Explore environment variables

```bash
printenv | sort | head -30
echo "$PATH" | tr ':' '\n'      # print PATH one directory per line

# Set a shell var vs an exported var, then start a child shell
myvar="local"
export myexp="inherited"
bash -c 'echo "child sees: myvar=[$myvar] myexp=[$myexp]"'
```

Notice the child sees `myexp` but not `myvar`.

### Step 4 — Extend your PATH

```bash
mkdir -p ~/bin
cat > ~/bin/hello << 'EOF'
#!/bin/bash
echo "Hello from my own PATH!"
EOF
chmod +x ~/bin/hello

hello                          # probably: command not found
export PATH="$HOME/bin:$PATH"
hello                          # now it runs
which hello
```

### Step 5 — Exit codes and chaining

```bash
true;  echo "true  -> $?"      # 0
false; echo "false -> $?"      # 1

grep -q root /etc/passwd && echo "root exists" || echo "no root"

# A command's own failure code
grep -q nobody-xyz /etc/passwd; echo "exit: $?"
```

### Step 6 — Make aliases and a function stick

```bash
cat >> ~/.bashrc << 'EOF'

# --- my devops aliases ---
alias ll='ls -alh'
alias ports='ss -tlnp'
alias myip='ip -4 addr show | grep inet'

# make a dir and enter it
mkcd() { mkdir -p "$1" && cd "$1"; }
EOF

source ~/.bashrc               # reload without logging out
ll
mkcd ~/scratch/test && pwd
```

### Step 7 — Clean up the markers from Step 2

```bash
# Remove the two echo lines you appended so your shell isn't noisy
sed -i '/\[loaded ~\/\.profile\]/d' ~/.profile
sed -i '/\[loaded ~\/\.bashrc\]/d'  ~/.bashrc
```

---

## Assignment

In `my-progress/day-05.md`:

1. **Precedence scenario:** You add a `PATH` change to `~/.bashrc`, but when you `vagrant ssh` in fresh it isn't applied — yet it works after you open a new shell inside the session. Explain *why* in terms of login vs. non-login shells, and state where you'd actually put the change so SSH logins pick it up.
2. **Make it yours:** Add **two** things to `~/.bashrc` that are genuinely useful to *you* and different from the lab's examples: one alias and one function that takes an argument (e.g. a `bak` function that copies a file to `<file>.bak`). Paste the additions and show them working after `source ~/.bashrc`.

---

## Further Reading

- `man bash` → the **INVOCATION** section explains startup file order precisely
- [Bash startup files, explained](https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html)
- [The Art of Command Line](https://github.com/jlevy/the-art-of-command-line)
- `help alias`, `help export`, `help function` — bash built-in help
