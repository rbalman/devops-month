# Contributing

Thanks for helping improve **DevOps Month**! This is a teaching resource, so contributions that make the material clearer, more correct, or more hands-on are especially valued.

## Ways to contribute

- **Fix a typo or a broken link**
- **Improve an explanation** that confused you as a learner
- **Fix or add an assignment / lab step**
- **Report a problem** by opening a [GitHub Issue](https://github.com/rbalman/devops-month/issues) — mistakes, unclear steps, commands that don't work
- **Add or expand content** for a day or week

If it's a bigger change, open an issue first so we can agree on the direction before you spend time on it.

## How to propose a change

1. **Fork** the repository and create a branch: `git checkout -b fix/day-05-typo`
2. Make your edits under `docs/`.
3. **Preview locally** to make sure it renders (see [README](README.md#run-the-site-locally)):
   ```bash
   pip install mkdocs-material
   mkdocs serve
   ```
4. Commit with a clear message and open a **Pull Request** describing what changed and why.

## Content guidelines

The course has a consistent shape — please match it so the days feel the same.

- **Follow the day template.** A daily lesson generally has: `Learning Objectives` → `Theory` → `Lab` (numbered steps) → `Advanced Topics` (topic + link only) → `Assignment` → `Further Reading`.
- **Keep it hands-on.** Prefer a runnable command with a short comment over a paragraph of prose.
- **Assignments** should be 1–2 per day, distinct from the lab, and increase in difficulty. Don't dictate which file learners must record work in — let them choose.
- **Only link to authentic, working resources.** Verify a URL resolves before adding it; prefer stable sources (official docs, `man` pages, well-known references).
- **Use Material admonitions** (`!!! note`, `!!! tip`, `!!! warning`, `!!! danger`) the way the existing pages do.
- **Keep the navigation in sync.** If you add, rename, or reorder a day, update **both**:
  - `mkdocs.yml` → the `nav:` section
  - `docs/schedule.md` → the schedule table

## Style

- Write for a beginner. Introduce a term in plain English the first time you use its abbreviation (e.g. "standard output (stdout)").
- Keep lines readable; wrap long prose naturally.
- Fenced code blocks should specify a language (```bash```) so they highlight and get a copy button.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) that covers this project.
