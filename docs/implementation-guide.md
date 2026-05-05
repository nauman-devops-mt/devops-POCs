# Implementation Guide — Semantic Tagging & Docker Pipeline

Complete step-by-step guide to implement this pipeline on a new repository.

---

## What This Implements

- Automated semantic versioning via PR labels (`patch` / `minor` / `major`)
- Git tags per environment (`devnet-vX.Y.Z`, `testnet-vX.Y.Z`, `vX.Y.Z`)
- Docker image built and pushed to DockerHub with the same tag
- GitHub Release created automatically on mainnet
- Slack notifications on success, failure, and skip
- Branch protection enforcing `feature → devnet → testnet → mainnet` flow

---

## Prerequisites

- GitHub repository (public for free branch protection)
- DockerHub account
- Slack workspace with Incoming Webhook access

---

## Step 1 — Create the three branches

```bash
git checkout main
git checkout -b devnet  && git push origin devnet  && git checkout main
git checkout -b testnet && git push origin testnet && git checkout main
git checkout -b mainnet && git push origin mainnet && git checkout main
```

---

## Step 2 — Add the workflow files

Create the following files in your repo:

### `.github/workflows/auto-tag.yml`

Copy from this repo and update line 12 with your DockerHub image name:
```yaml
env:
  DOCKERHUB_IMAGE: your-dockerhub-username/your-image-name
```

### `.github/workflows/require-version-label.yml`

Copy from this repo — no changes needed.

### `.github/workflows/require-source-branch.yml`

Copy from this repo — no changes needed.

### `Dockerfile`

Copy from this repo or write your own. The workflow passes `VERSION` as a build arg:
```dockerfile
FROM alpine:3.19
ARG VERSION=unknown
LABEL version="${VERSION}"
CMD ["echo", "your app"]
```

---

## Step 3 — Create GitHub Labels

Go to: `https://github.com/YOUR-ORG/YOUR-REPO/labels`

Create these 3 labels:

| Name    | Color     | Description                        |
|---------|-----------|------------------------------------|
| `patch` | `#0075ca` | Bug fixes, small changes           |
| `minor` | `#e4e669` | New features, backwards compatible |
| `major` | `#d93f0b` | Breaking changes                   |

---

## Step 4 — Add GitHub Secrets

Go to: **Settings → Secrets and variables → Actions → Secrets tab**

| Name                 | Value                        | How to get                                                                 |
|----------------------|------------------------------|----------------------------------------------------------------------------|
| `DOCKERHUB_USERNAME` | Your DockerHub username      | Your DockerHub login                                                       |
| `DOCKERHUB_TOKEN`    | DockerHub access token       | DockerHub → Account Settings → Security → New Access Token (Read & Write) |
| `SLACK_WEBHOOK_URL`  | Slack incoming webhook URL   | api.slack.com/apps → Create App → Incoming Webhooks → Add to Workspace    |

---

## Step 5 — Push everything to main

```bash
git add .github/workflows/ Dockerfile docs/
git commit -m 'ci: add semantic tagging and docker pipeline'
git push origin main
```

Then merge main into all three branches so they have the workflow files:

```bash
git checkout devnet  && git merge main --no-edit && git push origin devnet  && git checkout main
git checkout testnet && git merge main --no-edit && git push origin testnet && git checkout main
git checkout mainnet && git merge main --no-edit && git push origin mainnet && git checkout main
```

---

## Step 6 — Set up branch protection rules

Go to: **Settings → Branches → Add branch protection rule** — do this 3 times:

### devnet
- Branch name pattern: `devnet`
- ✅ Require a pull request before merging
- ✅ Require status checks to pass → add `Check version label`
- ✅ Do not allow bypassing the above settings

### testnet
- Branch name pattern: `testnet`
- ✅ Require a pull request before merging
- ✅ Require status checks to pass → add `Check source branch`
- ✅ Do not allow bypassing the above settings

### mainnet
- Branch name pattern: `mainnet`
- ✅ Require a pull request before merging
- ✅ Require status checks to pass → add `Check source branch`
- ✅ Do not allow bypassing the above settings

> **Note:** Status checks only appear in the search after the workflow has run at least once. Open a test PR first, then come back and add them.

---

## Step 7 — Test the full flow

### Test 1 — Label enforcement
```bash
git checkout -b feature/test
git commit --allow-empty -m 'test commit'
git push origin feature/test
```
Open PR → `devnet`. Without a label → merge is blocked. Add `minor` label → merge is allowed.

**Result:** `devnet-v0.1.0` tag + Docker image pushed to DockerHub

### Test 2 — Promotion devnet → testnet
Open PR from `devnet` → `testnet`. No label needed.

**Result:** `testnet-v0.1.0` tag + Docker image pushed

### Test 3 — Promotion testnet → mainnet
Open PR from `testnet` → `mainnet`. No label needed.

**Result:** `v0.1.0` tag + Docker image + GitHub Release created

### Test 4 — Wrong order (should be blocked)
Open PR from `devnet` → `mainnet`.

**Result:** `Check source branch` fails — merge is blocked ✅

---

## Pipeline Flow

```
feature branch
      │
      │  PR + label (patch / minor / major)
      ▼
   devnet ──────────────► devnet-vX.Y.Z  +  Docker image
      │
      │  PR (no label needed, auto-promotion)
      ▼
  testnet ─────────────► testnet-vX.Y.Z  +  Docker image
      │
      │  PR (no label needed, auto-promotion)
      ▼
  mainnet ─────────────► vX.Y.Z  +  Docker image  +  GitHub Release
```

---

## Version Bump Rules (devnet PRs only)

| Label   | Effect                    | Example             |
|---------|---------------------------|---------------------|
| `patch` | Increments last number    | `v1.0.0` → `v1.0.1` |
| `minor` | Increments middle number  | `v1.0.0` → `v1.1.0` |
| `major` | Increments first number   | `v1.0.0` → `v2.0.0` |

Testnet and mainnet always inherit the version from upstream — no bump calculation.

---

## Slack Notifications

| Status     | Trigger                                        |
|------------|------------------------------------------------|
| ✅ Success | Tag created + Docker image pushed successfully |
| ⏭️ Skipped | No label on PR or branch already up to date    |
| ❌ Failed  | Any step failed (build, tag push, image push)  |

---

## Workflow Files Reference

| File                                    | Purpose                                                             |
|-----------------------------------------|---------------------------------------------------------------------|
| `.github/workflows/auto-tag.yml`        | Main pipeline: version → build → tag → push → release → Slack     |
| `.github/workflows/require-version-label.yml` | Blocks devnet PRs without `patch`/`minor`/`major` label      |
| `.github/workflows/require-source-branch.yml` | Enforces devnet→testnet→mainnet promotion order              |
