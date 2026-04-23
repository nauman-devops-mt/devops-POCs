# Testing Guide — Semantic Auto-Tagging

---

## How It Works (Quick Summary)

- Push to any branch → workflow runs
- Tag is **only created** if a commit message contains `#patch`, `#minor`, or `#major`
- No keyword → no tag, workflow exits cleanly
- Merging devnet → testnet or testnet → mainnet **automatically inherits** the version (no keyword needed)

---

## Tag Format

| Branch  | Tag format        | Example          |
|---------|-------------------|------------------|
| devnet  | `devnet-vX.Y.Z`  | `devnet-v1.2.3`  |
| testnet | `testnet-vX.Y.Z` | `testnet-v1.2.3` |
| mainnet | `vX.Y.Z`         | `v1.2.3`         |

---

## Bump Keywords

Add anywhere in your commit message:

| Keyword  | What changes             | Example result (from `v1.2.2`) |
|----------|--------------------------|-------------------------------|
| `#patch` | last number              | `v1.2.3`                      |
| `#minor` | middle number, patch → 0 | `v1.3.0`                      |
| `#major` | first number, rest → 0   | `v2.0.0`                      |
| nothing  | no tag created           | —                             |

---

## Step 0 — One-time Setup

**Push the implementation to GitHub:**

```bash
git add .github/workflows/auto-tag.yml scripts/bump-version.sh docs/
git commit -m 'ci: semantic auto-tagging for devnet/testnet/mainnet'
git push origin main
```

**Create the three branches:**

```bash
git checkout -b devnet  && git push origin devnet  && git checkout main
git checkout -b testnet && git push origin testnet && git checkout main
git checkout -b mainnet && git push origin mainnet && git checkout main
```

Confirm on GitHub → **Branches** — you should see `devnet`, `testnet`, `mainnet`.

---

## Part 1 — Local Tests (no GitHub needed)

These use `--dry-run` — nothing is pushed, only shows what tag would be created.

### Test 1 — No keyword → no tag

```bash
git commit --allow-empty -m 'update config'
./scripts/bump-version.sh --branch devnet --dry-run
```

Expected:
```
No #major/#minor/#patch found — skipping.
```

---

### Test 2 — `#patch` bump

```bash
git tag devnet-v1.2.2
git commit --allow-empty -m 'fix: small fix #patch'
./scripts/bump-version.sh --branch devnet --dry-run
git tag -d devnet-v1.2.2
```

Expected:
```
New tag : devnet-v1.2.3  (bump: patch)
```

---

### Test 3 — `#minor` bump

```bash
git tag devnet-v1.2.2
git commit --allow-empty -m 'add new feature #minor'
./scripts/bump-version.sh --branch devnet --dry-run
git tag -d devnet-v1.2.2
```

Expected:
```
New tag : devnet-v1.3.0  (bump: minor)
```

---

### Test 4 — `#major` bump

```bash
git tag devnet-v1.2.2
git commit --allow-empty -m 'breaking change #major'
./scripts/bump-version.sh --branch devnet --dry-run
git tag -d devnet-v1.2.2
```

Expected:
```
New tag : devnet-v2.0.0  (bump: major)
```

---

### Test 5 — Promotion: devnet → testnet (no keyword needed)

```bash
git tag devnet-v1.5.0
git tag testnet-v1.2.0
./scripts/bump-version.sh --branch testnet --dry-run
git tag -d devnet-v1.5.0 testnet-v1.2.0
```

Expected:
```
Promotion: devnet 1.5.0 > testnet 1.2.0
New tag : testnet-v1.5.0  (bump: promotion)
```

---

### Test 6 — Promotion: testnet → mainnet (no keyword needed)

```bash
git tag testnet-v1.5.0
git tag v1.2.0
./scripts/bump-version.sh --branch mainnet --dry-run
git tag -d testnet-v1.5.0 v1.2.0
```

Expected:
```
Promotion: testnet 1.5.0 > mainnet 1.2.0
New tag : v1.5.0  (bump: promotion)
```

---

### Test 7 — No promotion (testnet already up to date), keyword required

```bash
git tag devnet-v1.5.0
git tag testnet-v1.5.0
git commit --allow-empty -m 'hotfix on testnet only #patch'
./scripts/bump-version.sh --branch testnet --dry-run
git tag -d devnet-v1.5.0 testnet-v1.5.0
```

Expected:
```
New tag : testnet-v1.5.1  (bump: patch)
```

---

### Test 8 — Idempotency (tag already exists, skip safely)

```bash
git tag devnet-v1.0.0
git commit --allow-empty -m 'something #patch'
# manually create the tag that would be generated
git tag devnet-v1.0.1
./scripts/bump-version.sh --branch devnet --dry-run
git tag -d devnet-v1.0.0 devnet-v1.0.1
```

Expected:
```
Tag devnet-v1.0.1 already exists — nothing to do.
```

---

## Part 2 — Live GitHub Actions Tests

Watch runs at: `https://github.com/<your-repo>/actions`

### Test A — Push without keyword → no tag

```bash
git checkout devnet
git commit --allow-empty -m 'update readme'
git push origin devnet
```

**Check Actions tab:** workflow runs, logs say `No #major/#minor/#patch found — skipping.`  
**Check Tags tab:** no new tag created.

---

### Test B — Push with `#patch` → tag created

```bash
git commit --allow-empty -m 'fix: connection issue #patch'
git push origin devnet
```

**Check Tags tab:** `devnet-v0.0.1` appears (or next patch from your last devnet tag).  
**Check Releases tab:** nothing — devnet does not create releases.

---

### Test C — Push with `#minor` → tag created

```bash
git commit --allow-empty -m 'add retry logic #minor'
git push origin devnet
```

**Check Tags tab:** `devnet-v0.1.0` (minor bump, patch reset to 0).

---

### Test D — Push with `#major` → tag created

```bash
git commit --allow-empty -m 'rename all routes #major'
git push origin devnet
```

**Check Tags tab:** `devnet-v1.0.0` (major bump, minor and patch reset to 0).

---

### Test E — Merge devnet → testnet (promotion, no keyword needed)

```bash
git checkout testnet
git merge devnet --no-edit
git push origin testnet
```

**Check Tags tab:** `testnet-v1.0.0` — same version as devnet, inherited automatically.  
**Check Releases tab:** nothing — testnet does not create releases.

---

### Test F — Direct hotfix on testnet (keyword required)

```bash
git checkout testnet
git commit --allow-empty -m 'urgent hotfix #patch'
git push origin testnet
```

**Check Tags tab:** `testnet-v1.0.1` — patch bump from testnet's own last tag.

---

### Test G — Merge testnet → mainnet (promotion, no keyword needed)

```bash
git checkout mainnet
git merge testnet --no-edit
git push origin mainnet
```

**Check Tags tab:** `v1.0.1` — version inherited from testnet.  
**Check Releases tab:** **GitHub Release `v1.0.1` created automatically** with changelog.

---

### Test H — Push to mainnet without keyword → no tag, no release

```bash
git checkout mainnet
git commit --allow-empty -m 'update docs'
git push origin mainnet
```

**Check Actions tab:** `No #major/#minor/#patch found — skipping.`  
**Check Releases tab:** no new release.

---

## Part 3 — Final Verification

After all tests, confirm the full tag list:

```bash
git fetch --tags
git tag --list | sort -V
```

Expected:
```
devnet-v0.0.1
devnet-v0.1.0
devnet-v1.0.0
testnet-v1.0.0
testnet-v1.0.1
v1.0.1
```

On GitHub → **Releases**: exactly **one** release (`v1.0.1`).  
On GitHub → **Tags**: all six tags listed above.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Workflow not triggering | Branch name doesn't match `devnet`, `testnet`, `mainnet` exactly | Check branch name spelling |
| Tag not created despite `#patch` in message | Commits since last tag don't include the keyword commit | Verify with `git log <last-tag>..HEAD` |
| `permission denied` pushing tag | Workflow missing `contents: write` | Check top of `auto-tag.yml` for `permissions: contents: write` |
| Tag already exists error | Pushed twice with same commits | Safe to ignore — idempotency check skips it |
| Promotion not detected | devnet/testnet versions already equal or behind | Check with `git tag --list \| sort -V` |
