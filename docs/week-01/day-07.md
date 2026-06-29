# Day 07 · Git & GitHub

## Learning Objectives

- Understand Git's core model: commits, branches, and the working tree
- Use Git for day-to-day version control
- Collaborate via GitHub: pull requests, issues, and code review

---

## Theory · ~20 min

### What is Git?

Git is a **distributed version control system**. It tracks changes to files over time and lets multiple people work on the same codebase without overwriting each other's work.

Every DevOps engineer uses Git constantly — not just for application code, but for infrastructure code (Terraform), configuration (Ansible), pipelines (GitHub Actions), and documentation.

### The Three Areas

```
Working Directory → Staging Area (Index) → Repository (.git)
      (edit files)         (git add)            (git commit)
```

- **Working Directory**: your files as you see them
- **Staging Area**: changes you've selected to include in the next commit
- **Repository**: the full history of commits

### Key Concepts

| Concept | What it is |
|---|---|
| **Commit** | A snapshot of staged changes with a message |
| **Branch** | A pointer to a commit; diverges from main to isolate work |
| **HEAD** | Where you currently are in the history |
| **Remote** | A copy of the repo on another machine (GitHub) |
| **Clone** | Download a repo from a remote |
| **Push** | Send your commits to the remote |
| **Pull** | Fetch + merge changes from the remote |
| **Merge** | Combine two branches |
| **Pull Request** | A GitHub mechanism to propose merging a branch |

### Good Commit Messages

```
# Bad
fix stuff
update
changes

# Good
day-05: add disk usage alert script
fix: nginx config missing server_name for port 443
feat: add Terraform module for VPC creation
```

Use the present tense, be specific, and reference what changed and why.

---

## Lab · ~50 min

### Step 1 — Core Git workflow

```bash
cd ~/devops-practice

# Initialize (already done if you've been committing)
git init     # only if not already a repo
git status

# Stage and commit
echo "learning git" > git-notes.txt
git status           # shows untracked file
git add git-notes.txt
git status           # shows staged
git commit -m "add git notes file"
git log --oneline    # see your commit history
```

### Step 2 — Branching

```bash
# Create and switch to a new branch
git checkout -b feature/add-readme

# Make changes
cat > README.md << 'EOF'
# DevOps Practice

My hands-on work for the DevOps Month course.
EOF

git add README.md
git commit -m "add README"

# See branches
git branch

# Switch back to main
git checkout main
ls                   # README.md is gone (it's on the feature branch)

# Merge the branch
git merge feature/add-readme
ls                   # README.md is back

# Delete the branch (cleanup)
git branch -d feature/add-readme
```

### Step 3 — Work with GitHub

```bash
# Add your fork as the remote (already done on day 01)
git remote -v

# Push your local main branch to GitHub
git push origin main

# Simulate a teammate's change by editing on GitHub:
# 1. Go to your fork on github.com
# 2. Edit README.md directly in the browser
# 3. Commit the change on GitHub

# Pull that change down locally
git pull origin main
git log --oneline   # the browser commit should appear
```

### Step 4 — Pull Request workflow

```bash
# Create a branch for a new feature
git checkout -b feature/day07-lab

# Add a meaningful file
mkdir -p my-progress/scripts
cat > my-progress/scripts/git_log_pretty.sh << 'EOF'
#!/bin/bash
# Show a pretty git log
git log --oneline --graph --decorate --all
EOF
chmod +x my-progress/scripts/git_log_pretty.sh

git add my-progress/
git commit -m "day-07: add pretty git log script"
git push origin feature/day07-lab
```

Now open GitHub, go to your fork, and create a Pull Request from `feature/day07-lab` → `main`. Add a description. Merge it. Then pull the merged changes locally:

```bash
git checkout main
git pull origin main
```

### Step 5 — Useful daily Git commands

```bash
git diff                    # what changed but not staged
git diff --staged           # what's staged but not committed
git log --oneline -10       # last 10 commits
git show HEAD               # details of latest commit
git stash                   # temporarily shelve changes
git stash pop               # restore shelved changes
git blame README.md         # who last changed each line
```

---

## Assignment

In `my-progress/day-07.md`:

1. What is the difference between `git pull` and `git fetch`?
2. What happens if two people edit the same line of a file and both try to push? How do you resolve it?
3. Create a branch called `experiment/test-branch`, commit something to it, then merge it into `main` and delete the branch. Paste the `git log --oneline` output showing the merge.
4. When would you use `git stash`? Give a real-world scenario.

```bash
git add my-progress/day-07.md
git commit -m "day-07: git and github complete"
git push origin main
```

---

## Further Reading

- [git - the simple guide](https://rogerdudler.github.io/git-guide/)
- [Oh Shit, Git!](https://ohshitgit.com/) — what to do when things go wrong
- [Conventional Commits](https://www.conventionalcommits.org/) — a standard for commit messages
- [GitHub Skills](https://skills.github.com/) — free interactive GitHub courses
