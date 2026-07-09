# DevOps Month

> A hands-on, 30-day DevOps course for beginners.

[![Live Site](https://img.shields.io/badge/site-devops--month-indigo)](https://rbalman.github.io/devops-month)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

This is not a lecture series. Every day is built around **doing** — spinning up servers, writing scripts, deploying apps, and debugging real issues. The theory is here to support the practice, not the other way around.

📖 **Read it online: [rbalman.github.io/devops-month](https://rbalman.github.io/devops-month)**

## What you'll learn

Over 30 days you go from the Linux command line to a full deployment pipeline: code on GitHub → built and tested by GitHub Actions → shipped as a container to an AWS server → monitored with Prometheus, Loki, and Grafana.

| Week | Theme |
|---|---|
| **Week 1** | Linux System Administration — filesystem, processes, permissions, the shell, scripting |
| **Week 2** | Networking & Containers |
| **Week 3** | Infrastructure as Code & Cloud |
| **Week 4** | CI/CD & Monitoring |

Each session is **1–1.5 hours**: ~20 min theory + ~50 min hands-on lab + a take-home assignment. See the full [Schedule](docs/schedule.md).

## Who it's for

- Students (final year preferred) and recent graduates targeting a first DevOps/SRE/infrastructure role
- Anyone comfortable with basic programming, networking, and Git who wants hands-on practice

## Repository layout

```
devops-month/
├── docs/                   # all course content (Markdown, served by MkDocs)
│   ├── index.md            # course home page
│   ├── schedule.md         # the 30-day plan
│   ├── resources.md        # extra references
│   ├── slides/             # presentation slides
│   └── week-01 … week-04/  # daily lessons
├── mkdocs.yml              # site configuration & navigation
├── .github/workflows/      # GitHub Pages deploy pipeline
├── CONTRIBUTING.md         # how to propose changes
└── LICENSE                 # MIT
```

The site is built with [MkDocs](https://www.mkdocs.org/) + [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) and deployed to GitHub Pages automatically on every push to `main`.

## Run the site locally

You only need this if you want to preview changes to the content.

```bash
# (optional but recommended) create a virtual environment
python3 -m venv .venv && source .venv/bin/activate

# install the one dependency
pip install mkdocs-material

# live-reloading preview at http://127.0.0.1:8000
mkdocs serve

# or produce the static site in ./site
mkdocs build
```

## Contributing

Corrections, clearer explanations, better assignments, and new content are all welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the quick guide.

## License

Released under the [MIT License](LICENSE). You are free to use, adapt, and share the material — attribution is appreciated.

Maintained by [Balman Rawat](https://balmanrawat.com.np).
