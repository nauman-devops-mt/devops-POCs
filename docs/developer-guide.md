# Developer Guide — How to Merge Code

---

## The Pipeline

All code flows in one direction only:

```
feature branch  →  devnet  →  testnet  →  mainnet
```

- **Never** push directly to `devnet`, `testnet`, or `mainnet`
- All changes must go through a **Pull Request**
- Tags and releases are created **automatically** — you do not create them manually

---

## Tag Format

| Branch  | Auto-created tag | Example          |
|---------|------------------|------------------|
| devnet  | `devnet-vX.Y.Z`  | `devnet-v1.2.0`  |
| testnet | `testnet-vX.Y.Z` | `testnet-v1.2.0` |
| mainnet | `vX.Y.Z`         | `v1.2.0`         |

---

## Step 1 — Start from devnet

Always create your feature branch from `devnet`:

```bash
git checkout devnet
git pull origin devnet
git checkout -b feature/your-feature-name
```

---

## Step 2 — Make your changes and push

```bash
git add .
git commit -m 'describe your change'
git push origin feature/your-feature-name
```

---

## Step 3 — Open a PR to devnet (label required)

1. Go to GitHub → **Pull requests** → **New pull request**
2. Set **base:** `devnet` ← **compare:** `feature/your-feature-name`
3. Add a title and description
4. **Add exactly one version label:**

| Label | When to use | Version change |
|---|---|---|
| `patch` | Bug fix, typo, config update, small tweak | `v1.0.0` → `v1.0.1` |
| `minor` | New feature, backwards compatible addition | `v1.0.0` → `v1.1.0` |
| `major` | Breaking change, renamed API, removed endpoint | `v1.0.0` → `v2.0.0` |

5. The PR **cannot be merged** without a label — the check will block it
6. Get approval if required → **Merge**

**What happens automatically:** `devnet-v1.1.0` tag is created on devnet ✓

---

## Step 4 — Promote devnet → testnet (no label needed)

Once devnet has been tested and is ready for staging:

1. GitHub → **New pull request**
2. **base:** `testnet` ← **compare:** `devnet`
3. Title: `Promote devnet to testnet`
4. **No label needed** — version is inherited from devnet automatically
5. Merge

**What happens automatically:** `testnet-v1.1.0` tag is created on testnet ✓

---

## Step 5 — Promote testnet → mainnet (no label needed)

Once testnet has been verified and is ready for production:

1. GitHub → **New pull request**
2. **base:** `mainnet` ← **compare:** `testnet`
3. Title: `Promote testnet to mainnet`
4. **No label needed** — version is inherited from testnet automatically
5. Merge

**What happens automatically:** `v1.1.0` tag + GitHub Release created on mainnet ✓

---

## Choosing the right label

```
Fixed a bug                          → patch   v1.0.0 → v1.0.1
Updated a config value               → patch   v1.0.0 → v1.0.1
Added a new feature or endpoint      → minor   v1.0.0 → v1.1.0
Changed behaviour that breaks others → major   v1.0.0 → v2.0.0
Renamed or removed an existing API   → major   v1.0.0 → v2.0.0
```

**When in doubt, use `patch`.** You can always bump `minor` on the next PR.

---

## Rules

| Do | Don't |
|---|---|
| Always branch off from `devnet` | Branch off from `main`, `testnet`, or `mainnet` |
| One label per devnet PR | Add multiple labels — `major` always wins |
| Promote in order: devnet → testnet → mainnet | Skip testnet and merge devnet directly to mainnet |
| Open one PR at a time per environment | Open a testnet PR before devnet is merged and tagged |
| Use descriptive branch names | Push directly to `devnet`, `testnet`, or `mainnet` |

---

## Full example

```
1. git checkout devnet && git pull origin devnet
2. git checkout -b feature/add-retry-logic
3. # make changes
4. git commit -m 'add retry logic for failed requests'
5. git push origin feature/add-retry-logic

6. GitHub: Open PR  feature/add-retry-logic → devnet
           Add label: minor
           Merge PR
           → devnet-v1.1.0 created automatically

7. GitHub: Open PR  devnet → testnet
           No label needed
           Merge PR
           → testnet-v1.1.0 created automatically

8. GitHub: Open PR  testnet → mainnet
           No label needed
           Merge PR
           → v1.1.0 created + GitHub Release published automatically
```

---

## Verify tags after merging

```bash
git fetch --tags
git tag --list | sort -V
```

Or on GitHub → **Tags** tab to see all tags with their commits.
