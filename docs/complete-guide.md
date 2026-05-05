# Complete Guide — CI/CD Pipeline & Release Workflow

This guide explains the full automated release pipeline, how it works, and exactly what developers need to do when merging code.

---

## Overview

Every code change goes through three environments before reaching production:

```
Your Code  →  devnet  →  testnet  →  mainnet (production)
              (dev)       (staging)    (live)
```

Everything after your PR is merged happens **automatically**:
- Version tag is created on the branch
- Docker image is built and pushed to DockerHub
- GitHub Release is published (mainnet only)
- Slack notification is sent to the team

You never create tags, build images, or make releases manually.

---

## Environments & Tags

| Environment | Branch    | Git Tag          | DockerHub Image                      | GitHub Release |
|-------------|-----------|------------------|--------------------------------------|----------------|
| Development | `devnet`  | `devnet-v1.2.0`  | `org/app:devnet-v1.2.0`              | No             |
| Staging     | `testnet` | `testnet-v1.2.0` | `org/app:testnet-v1.2.0`             | No             |
| Production  | `mainnet` | `v1.2.0`         | `org/app:v1.2.0` + `org/app:latest`  | Yes            |

---

## Branch Strategy

```
main (source of truth)
  │
  ├── feature/your-feature    ← you work here
  ├── feature/another-thing   ← or here
  │
  ▼
devnet   ← features land here first
  │
  ▼
testnet  ← promoted from devnet after testing
  │
  ▼
mainnet  ← promoted from testnet, goes live
```

**Rules:**
- Never push directly to `devnet`, `testnet`, or `mainnet` — all changes go through Pull Requests
- `devnet` accepts PRs from any feature branch
- `testnet` only accepts PRs from `devnet`
- `mainnet` only accepts PRs from `testnet`

---

## The Full Developer Workflow

### 1. Start from devnet

Always create your feature branch from `devnet` (not `main`):

```bash
git checkout devnet
git pull origin devnet
git checkout -b feature/your-feature-name
```

### 2. Write your code and push

```bash
git add .
git commit -m 'describe what you changed'
git push origin feature/your-feature-name
```

### 3. Open a PR to devnet — pick a version label

Go to GitHub → **Pull Requests** → **New pull request**

- **base:** `devnet`
- **compare:** `feature/your-feature-name`

**Before merging, add exactly one label:**

| Label   | Use when                                              | Version change       |
|---------|-------------------------------------------------------|----------------------|
| `patch` | Bug fix, typo, config tweak, dependency update        | `v1.2.3` → `v1.2.4` |
| `minor` | New feature, new endpoint, new behaviour (non-breaking) | `v1.2.3` → `v1.3.0` |
| `major` | Breaking change, renamed/removed API, changed contract | `v1.2.3` → `v2.0.0` |

> The PR **cannot be merged** without one of these labels. The check will block it.

**After merge:** `devnet-v1.3.0` tag is created and Docker image is pushed automatically.

---

### 4. Promote devnet → testnet

Once the feature is tested on devnet and ready for staging:

1. Open PR: **base:** `testnet` ← **compare:** `devnet`
2. Title: `Promote devnet to testnet`
3. **No label needed**
4. Get approval if required → Merge

**After merge:** `testnet-v1.3.0` tag is created — same version as devnet, inherited automatically.

---

### 5. Promote testnet → mainnet

Once staging is verified and ready for production:

1. Open PR: **base:** `mainnet` ← **compare:** `testnet`
2. Title: `Promote testnet to mainnet`
3. **No label needed**
4. Get approval if required → Merge

**After merge:**
- `v1.3.0` tag is created
- Docker image pushed as `org/app:v1.3.0` and `org/app:latest`
- GitHub Release `v1.3.0` published automatically with changelog

---

## What Happens Automatically (Pipeline Steps)

When a PR is merged, this runs in order:

```
① Compute next version
        │
        ▼
② Login to DockerHub
        │
        ▼
③ Build Docker image       ← if this FAILS → no tag is created, failure alert sent
        │
        ▼
④ Create git tag           ← only runs if build succeeded
        │
        ▼
⑤ Push image to DockerHub  ← only runs if tag was created
        │
        ▼
⑥ Create GitHub Release    ← mainnet only
        │
        ▼
⑦ Send Slack notification
```

If any step fails, all subsequent steps are skipped and a ❌ failure notification is sent to Slack.

---

## Choosing the Right Label

```
"I fixed a bug"                             → patch
"I updated a config value"                  → patch
"I added a new API endpoint"                → minor
"I added a new feature"                     → minor
"I renamed an existing API endpoint"        → major
"I changed the response format of an API"   → major
"I removed a feature others depend on"      → major
```

**When in doubt, use `patch`.** It's always safe to bump `minor` or `major` on the next PR once the impact is clear.

---

## Versioning Rules

Version format: `MAJOR.MINOR.PATCH`

| Part    | When it changes                                       | Example             |
|---------|-------------------------------------------------------|---------------------|
| `MAJOR` | Breaking changes — existing code will break           | `1.0.0` → `2.0.0`  |
| `MINOR` | New features — existing code still works              | `1.0.0` → `1.1.0`  |
| `PATCH` | Bug fixes, small changes — nothing new or broken      | `1.0.0` → `1.0.1`  |

The version always bumps from the **last devnet tag**. Testnet and mainnet inherit it — no extra bumping.

---

## Slack Notifications

The team receives a Slack notification after every PR merge:

| Notification | When                                          | Includes                                      |
|--------------|-----------------------------------------------|-----------------------------------------------|
| ✅ Success   | Tag created, image pushed successfully        | Repo, branch, tag, Docker image, triggered by |
| ⏭️ Skipped   | No label on PR, or env already up to date     | Repo, branch, reason, triggered by            |
| ❌ Failed    | Build failed, tag push failed, image push failed | Repo, branch, triggered by, link to logs   |

---

## What Gets Blocked and Why

| Action | Blocked by | How to fix |
|---|---|---|
| Direct push to `devnet` / `testnet` / `mainnet` | Branch protection | Open a PR instead |
| PR to `devnet` without `patch`/`minor`/`major` label | `Check version label` | Add a label to the PR |
| PR from `feature` branch directly to `testnet` | `Check source branch` | Merge to `devnet` first |
| PR from `feature` branch directly to `mainnet` | `Check source branch` | Go through `devnet` then `testnet` |
| PR from `devnet` directly to `mainnet` | `Check source branch` | Merge devnet→testnet first |

---

## Quick Reference

```bash
# Start new work
git checkout devnet && git pull origin devnet
git checkout -b feature/my-feature

# Push and open PR to devnet (add patch/minor/major label)
git push origin feature/my-feature

# ── GitHub: PR feature → devnet (with label) → merge ──────────────
# Automatic: devnet-vX.Y.Z tag + Docker image

# ── GitHub: PR devnet → testnet (no label) → merge ────────────────
# Automatic: testnet-vX.Y.Z tag + Docker image

# ── GitHub: PR testnet → mainnet (no label) → merge ───────────────
# Automatic: vX.Y.Z tag + Docker image + GitHub Release
```

---

## Verifying Tags and Releases

**Check all tags:**
```bash
git fetch --tags
git tag --list | sort -V
```

**Check DockerHub:** `https://hub.docker.com/r/YOUR-ORG/YOUR-IMAGE/tags`

**Check GitHub Releases:** `https://github.com/YOUR-ORG/YOUR-REPO/releases`

---

## FAQ

**Q: I merged to devnet but no tag was created.**
Check the PR had a `patch`, `minor`, or `major` label. Check GitHub Actions tab for the workflow run.

**Q: My PR to testnet is blocked.**
The PR must come from `devnet`. You cannot open a PR from a feature branch directly to testnet.

**Q: I used the wrong label (e.g. `patch` instead of `minor`).**
Not a problem — open another PR to devnet with the correct label for your next change. The version will bump correctly from where it left off.

**Q: Two people merged to devnet at the same time. Which version wins?**
Whichever PR merges second will bump from the version created by the first merge. Both get unique tags with no conflict.

**Q: Can I merge mainnet back into devnet?**
No. Code only flows one way: `feature → devnet → testnet → mainnet`. Merging backwards creates messy history and incorrect tags.

**Q: The Docker build failed. Was a tag created?**
No. The git tag is only created after the Docker build succeeds. Fix the Dockerfile issue and open a new PR.
