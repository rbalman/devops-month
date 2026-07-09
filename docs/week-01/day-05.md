# Day 05 · The Shell — Types, Config & Environment

## Learning Objectives

- Understand what a shell is and the difference between common shells
- Know where your interactive shell config lives (`~/.bashrc`) and what belongs in it
- Work with environment variables and understand how they're inherited
- Redirect the standard streams (stdin, stdout, stderr) to and from files
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

### Shell config files

When bash starts, it reads a config file so your customisations — aliases, functions, `PATH` tweaks — are there every time. Bash actually has several such files, but for now we'll use just one:

- **`~/.bashrc`** — your personal bash config. This is where you put aliases, functions, and environment tweaks. It's re-read every time you open an interactive shell.

```bash
ls -la ~ | grep bashrc     # your ~/.bashrc
source ~/.bashrc           # re-read it in the current shell after editing
```

!!! tip "The practical rule for now"
    Put your **aliases, functions, `PATH` additions, and environment variables** in `~/.bashrc`. Edit the file, then run `source ~/.bashrc` to apply the changes without logging out.

    Bash has other startup files (`~/.profile`, `~/.bash_profile`, `/etc/profile`) that load in a specific order depending on *how* the shell was started. You don't need them yet — see [Advanced Topics](#advanced-topics) if you're curious.

### Variables

A variable stores a value under a name. Set it with `name=value` (no spaces around `=`) and read it back with `$name`. By default it's a **shell variable** — it lives only in the current shell.

```bash
name="balman"      # set
echo "$name"       # read
unset name         # remove
```

Bash also predefines variables that **control how the shell itself behaves and looks**, not data for other programs. The one you'll see most is `PS1`, your prompt:

```bash
echo "$PS1"                # your current prompt definition
PS1='\u@\h:\w\$ '          # user@host:working-dir$  — the prompt changes instantly
```

Inside `PS1`, backslash escapes expand to live values: `\u` user, `\h` hostname, `\w` working dir, `\$` a `#` for root else `$`. Set it permanently in `~/.bashrc`.

| Variable | Purpose |
|---|---|
| `PS1` | Primary prompt shown before each command |
| `PS2` | Continuation prompt for multi-line commands (default `>`) |
| `IFS` | Internal Field Separator — characters bash splits words on (space/tab/newline) |
| `HISTSIZE` | How many commands to keep in the in-memory history |
| `HISTFILE` | File where history is saved (`~/.bash_history`) |
| `HISTCONTROL` | History cleanup rules, e.g. `ignoredups` |

A few are **read-only** — bash sets them, you just read them:

| Variable | Purpose |
|---|---|
| `$?` | Exit code of the last command (see below) |
| `$$` | PID of the current shell |
| `RANDOM` | A new random integer each time it's read |
| `SECONDS` | Seconds since the shell started |
| `BASH_VERSION` | Version of the running bash |

### Environment variables

An **environment variable** is a shell variable you've `export`ed so that child processes inherit it.

```bash
export EDITOR="vim"    # exported → inherited by any program you launch
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

### Variables vs. environment variables

The only difference is `export`:

- A plain **shell variable** stays in the current shell and is invisible to programs and child shells you start. Use it for temporary values you need right here.
- An **environment variable** is exported, so every child process inherits it. Use it when a program you launch needs to read the value (`PATH`, `EDITOR`, `AWS_REGION`, …).

```bash
myvar="local"          # shell variable
export myexp="shared"  # environment variable
bash -c 'echo "child sees: [$myvar] [$myexp]"'   # only myexp is visible
```

Rule of thumb: keep it a shell variable unless something you launch needs it — then `export`.

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

### Standard streams: stdin, stdout, stderr

Every command talks through three **standard streams**. Picture a program as a box with one intake pipe and two output pipes:

- **stdin** *(standard input)* — where it **reads** input from. Default: your keyboard.
- **stdout** *(standard output)* — where it writes its **normal results**. Default: your screen.
- **stderr** *(standard error)* — where it writes **error and diagnostic messages**. Default: your screen too.

The two output streams are separate on purpose — it lets you keep the real results while throwing errors away (or the reverse). They both land on your screen by default, which is why normal output and errors look mixed together until you redirect them apart. Each stream has a number, its **file descriptor**: `0` = stdin, `1` = stdout, `2` = stderr.

**Redirection** re-plumbs a stream to a file instead of the screen:

```bash
date > out.txt                 # stdout → file, overwrite   ( '>' is short for '1>' )
echo "one more line" >> out.txt  # stdout → file, append
ls /nope 2> err.txt            # stderr → file (the "cannot access" message)
ls /etc /nope > out.txt 2> err.txt   # results and errors into separate files
ls /etc /nope > all.txt 2>&1   # BOTH streams into one file
sort < out.txt                 # feed a file into stdin
```

`/dev/null` is the system "black hole" — redirect to it to discard output you don't care about:

```bash
find / -name "*.conf" 2>/dev/null   # show the matches, silently drop "Permission denied" errors
```

!!! tip "How to read `2>&1`"
    "Send stream **2** (stderr) to wherever stream **1** (stdout) is currently going." Order matters: put it **after** the `>` that sets where stdout goes, or the errors won't follow.

A pipe (`|`, from Day 2) is just redirection between two commands: it connects the **stdout** of the left command to the **stdin** of the right one. (A plain pipe carries stdout only — not stderr.)

### Exit / status codes

Besides its output streams, every command also reports a numeric **exit code** when it finishes. `0` means success; anything else (1–255) means some kind of failure. Scripts and automation live or die by this.

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

---

## Lab · ~45 min

Work **inside your Vagrant VM** (`vagrant ssh`).

### Step 1 — Identify your shell and its config

```bash
echo $0
echo $SHELL
cat /etc/shells
ls -la ~ | grep bashrc          # your ~/.bashrc config file
```

### Step 2 — Explore environment variables

```bash
printenv | sort | head -30
echo "$PATH" | tr ':' '\n'      # print PATH one directory per line

# Set a shell var vs an exported var, then start a child shell
myvar="local"
export myexp="inherited"
bash -c 'echo "child sees: myvar=[$myvar] myexp=[$myexp]"'
```

Notice the child sees `myexp` but not `myvar`.

### Step 3 — Extend your PATH

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

### Step 4 — Redirect the standard streams

```bash
# This command succeeds on /etc but errors on /nope — output goes to stdout, the error to stderr
ls /etc /nope

ls /etc /nope > out.txt          # only normal output is captured; the error STILL hits your screen
cat out.txt

ls /etc /nope > out.txt 2> err.txt   # split the two streams into separate files
cat err.txt                          # the "cannot access '/nope'" message landed here

ls /etc /nope > all.txt 2>&1     # merge BOTH streams into one file
find /etc -name "*.conf" 2>/dev/null | head   # discard errors, keep and pipe the results
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

---

## Advanced Topics

We kept things to `~/.bashrc` on purpose. These are the next concepts to explore on your own — read the linked resource for each:

- **Login vs. non-login, interactive vs. non-interactive shells** — how a shell is started decides which config files it reads → [`man bash` — INVOCATION](https://man7.org/linux/man-pages/man1/bash.1.html)
- **Startup file precedence** — the order bash reads `/etc/profile`, `~/.bash_profile`, `~/.profile`, and `~/.bashrc` → [Bash Startup Files — GNU manual](https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html)
- **Setting environment variables persistently** — where `PATH` and other exports belong so logins pick them up → [Ubuntu community — EnvironmentVariables](https://help.ubuntu.com/community/EnvironmentVariables)
- **Customising your prompt (`PS1`) and other special variables** — the full list of predefined bash variables and prompt escapes → [Bash Variables](https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html) · [Controlling the Prompt](https://www.gnu.org/software/bash/manual/html_node/Controlling-the-Prompt.html)

---

## Assignment

1. **Master the shortcuts:** Work through this [Bash shortcuts & navigation cheatsheet](https://gist.github.com/tuxfight3r/60051ac67c5f0445efee). Practise moving and editing on the command line without arrow keys — jump to line start/end (`Ctrl-a` / `Ctrl-e`), delete a word (`Ctrl-w`), search history (`Ctrl-r`), recall the last argument (`Alt-.`) — until they're muscle memory. Pick the five you'll use most and note what each does.
2. **Customise your prompt:** Change `PS1` so your prompt shows username, host, and current directory, and make the change permanent so it survives opening a new shell.

---

## Further Reading

- [The Art of Command Line](https://github.com/jlevy/the-art-of-command-line)
- `help alias`, `help export`, `help function` — bash built-in help
- Startup files and their precedence are covered in [Advanced Topics](#advanced-topics) above
