# Semantic Auto-Tagging Strategy
## devnet / testnet / mainnet Branch Pipeline

---

## Overview

This document describes the automated semantic versioning and tagging strategy for the three-environment branch pipeline. Tags are created automatically on every push or merge — no manual tagging required.

The core principle is **version promotion**: when code moves up the environment chain, the version number is inherited rather than recalculated. Conventional commits drive version bumps only on the origin branch (`devnet`) or on direct hotfixes.

---

## Environment Pipeline

```
devnet  ──►  testnet  ──►  mainnet
(dev)        (staging)     (production)
```

---

## Tag Format

| Branch   | Tag Format       | Example           | GitHub Release? |
|----------|------------------|-------------------|-----------------|
| devnet   | `devnet-vX.Y.Z`  | `devnet-v1.3.1`   | No (git tag only) |
| testnet  | `testnet-vX.Y.Z` | `testnet-v1.3.1`  | No (git tag only) |
| mainnet  | `vX.Y.Z`         | `v1.3.1`          | Yes (stable release) |

Git tags are global — the branch prefix (`devnet-`, `testnet-`) keeps tags from different environments from colliding.

---

## Versioning Rules

### Semantic Version Components

Follows [Semantic Versioning 2.0.0](https://semver.org/):

| Version Part | When it increments |
|---|---|
| **MAJOR** (`X`) | Breaking change — commit contains `BREAKING CHANGE` in body, or `!:` in type (e.g. `feat!: ...`) |
| **MINOR** (`Y`) | New feature — commit starts with `feat:` or `feat(scope):` |
| **PATCH** (`Z`) | Everything else — `fix:`, `chore:`, `docs:`, `refactor:`, `ci:`, plain text, merge commit messages |

### Per-Branch Logic

#### devnet — Conventional Commits (always)

Every push to `devnet` is analyzed using conventional commits:

1. Find the latest `devnet-vX.Y.Z` tag. If none exists, fall back to the latest stable mainnet `vX.Y.Z` tag. If that doesn't exist either, start from `v0.0.0`.
2. Analyze all commits since that tag.
3. Determine bump level (MAJOR / MINOR / PATCH).
4. Create new tag `devnet-vX.Y.Z`.

#### testnet — Promotion-Aware

Every push/merge to `testnet` checks whether it is a promotion from devnet or a direct push:

| Condition | Action |
|---|---|
| Latest `devnet` version **>** latest `testnet` version | **PROMOTION** — inherit version: create `testnet-v{devnet_version}`. Commit messages ignored. |
| Latest `devnet` version **≤** latest `testnet` version | **DIRECT PUSH** — analyze commits since last `testnet-v*` tag using conventional commits, apply bump, create `testnet-vX.Y.Z`. |

#### mainnet — Promotion-Aware

Every push/merge to `mainnet` checks whether it is a promotion from testnet or a direct push:

| Condition | Action |
|---|---|
| Latest `testnet` version **>** latest `mainnet` version | **PROMOTION** — inherit version: create `v{testnet_version}`. Commit messages ignored. GitHub Release created. |
| Latest `testnet` version **≤** latest `mainnet` version | **DIRECT PUSH** — analyze commits since last `v*` tag using conventional commits, apply bump, create `vX.Y.Z`. GitHub Release created. |

---

## Step-by-Step Example

Starting state: `mainnet` is at `v1.0.0`. No `devnet` or `testnet` tags yet.

```
Step 1 — Developer pushes a bugfix to devnet
  Commit:  fix: resolve connection timeout
  devnet base (none) → fallback to mainnet base v1.0.0
  Bump:    patch
  Tag:     devnet-v1.0.1

Step 2 — Developer pushes a new feature to devnet
  Commit:  feat: add retry logic
  devnet base: 1.0.1
  Bump:    minor
  Tag:     devnet-v1.1.0

Step 3 — devnet is merged into testnet
  Merge commit: "Merge branch 'devnet' into testnet"
  devnet base (1.1.0) > testnet base (none/0.0.0) → PROMOTION
  Tag:     testnet-v1.1.0  ← version inherited from devnet, no commit analysis

Step 4 — Hotfix pushed directly to testnet
  Commit:  fix: edge case in retry logic
  testnet base (1.1.0) >= devnet base (1.1.0) → DIRECT PUSH
  Bump:    patch
  Tag:     testnet-v1.1.1

Step 5 — testnet is merged into mainnet
  Merge commit: "Merge branch 'testnet' into mainnet"
  testnet base (1.1.1) > mainnet base (1.0.0) → PROMOTION
  Tag:     v1.1.1  ← version inherited from testnet, no commit analysis
  Action:  GitHub Release v1.1.1 created automatically
```

---

## Edge Cases

### No conventional commit markers
Any commit message that does not match `feat:`, `feat!:`, or contain `BREAKING CHANGE` is treated as a **patch** bump. This includes:
- Plain text commits (`"update config"`, `"wip"`)
- Merge commit messages (`"Merge branch 'feature' into devnet"`)
- Squash commit messages that don't follow conventional commits

### Duplicate push / re-run safety
Before creating any tag, the workflow checks whether that exact tag already exists. If it does, the step is skipped. This makes the workflow **idempotent** — safe to re-run without creating duplicate tags.

### First-ever run (no tags anywhere)
All branches fall back to `v0.0.0` as the virtual starting point. The first push to `devnet` will produce `devnet-v0.0.1` (patch bump).

### Skipping environments (devnet → mainnet directly)
If code is merged directly from `devnet` to `mainnet` (bypassing testnet), mainnet checks the **testnet** version. If no testnet tag is ahead, it falls through to conventional commits on mainnet. To ensure the devnet version is honored in this case, the recommended practice is to always promote through testnet first.

---

## Implementation

### GitHub Actions Workflow

**File:** `.github/workflows/auto-tag.yml`

- Triggers on push to `devnet`, `testnet`, `mainnet`
- Runs full promotion-aware version computation in shell
- Creates an annotated git tag and pushes it
- Creates a GitHub Release (mainnet only) using `softprops/action-gh-release@v2`
- Requires `contents: write` permission

### Local Bump Script

**File:** `scripts/bump-version.sh`

Mirrors the same logic for local use:

```bash
# Preview next version without creating a tag
./scripts/bump-version.sh --branch devnet --dry-run

# Create and push the tag
./scripts/bump-version.sh --branch testnet
```

---

## Commit Message Convention Reference

```
<type>[optional scope]: <description>

[optional body]

[optional footer — BREAKING CHANGE: <description>]
```

| Type | Bump | Example |
|---|---|---|
| `feat` | minor | `feat: add stake delegation endpoint` |
| `feat!` | major | `feat!: rename all API endpoints` |
| `fix` | patch | `fix: handle null pointer in validator` |
| `chore` | patch | `chore: update dependencies` |
| `docs` | patch | `docs: update README` |
| `refactor` | patch | `refactor: simplify retry logic` |
| `BREAKING CHANGE` in footer | major | `fix: update token format\n\nBREAKING CHANGE: token format changed` |
