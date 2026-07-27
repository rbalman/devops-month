# Sample CI/CD App

A complete, runnable version of the sample app used in **Week 4, Day 1** to build a
first CI pipeline. It's a tiny **Node.js / Express API** with one test and a lint
config — the smallest thing with something real to *lint, test, and build* — plus
the **GitHub Actions workflow** that does exactly that on every push and pull request.

> The API is deliberately minimal. The point of Day 1 isn't the app — it's the
> **pipeline**. Use this as the reference app so you can focus on the workflow.

## Structure

```
first-pipeline/
├── .github/
│   └── workflows/
│       └── ci.yml          # the CI pipeline: install → lint → test → build
└── api/
    ├── app.js              # the Express app (exported so tests can import it)
    ├── server.js           # starts the app (kept separate so tests don't open a port)
    ├── app.test.js         # one test — hits GET /healthz
    ├── eslint.config.js    # minimal ESLint flat config
    ├── package.json        # scripts: start / test / lint
    └── package-lock.json   # exact dependency versions (required by `npm ci`)
```

> **Verified on Ubuntu 24.04 + Node 24** (the course target). `node_modules/` is
> git-ignored — run `npm ci` to install from the lockfile.

## Run it locally

On an Ubuntu 24.04 machine (your Vagrant box or EC2), install Node 24, then:

```bash
cd api
npm ci                # install exactly what's in package-lock.json
npm run lint          # eslint .
npm test              # jest — the /healthz test
npm start             # runs on http://localhost:3000
```

```bash
curl localhost:3000/healthz     # {"status":"ok"}
```

If you don't have Node yet:

```bash
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## The pipeline

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push, pull
request, and manual dispatch. It checks out the code, sets up Node 24 (with npm
caching), then runs **install → lint → test → build** — each a gate that stops the
pipeline if it fails. To use it in your own repo, copy this whole folder to the repo
root; GitHub reads workflows from `.github/workflows/` at the **repo root** (not from
inside `examples/`), so the reference copy here doesn't run in this repo — it's yours
to copy.

See [Week 4, Day 1](../../../docs/week-04/day-22.md) for the full walkthrough.
