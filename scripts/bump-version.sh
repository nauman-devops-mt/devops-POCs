#!/usr/bin/env bash
# Local version bump script — mirrors the PR-label logic in auto-tag.yml.
#
# Usage:
#   ./scripts/bump-version.sh --branch devnet  --bump minor [--dry-run]
#   ./scripts/bump-version.sh --branch testnet [--dry-run]   # promotion only
#   ./scripts/bump-version.sh --branch mainnet [--dry-run]   # promotion only
#
# --branch   Target branch: devnet | testnet | mainnet (default: current branch)
# --bump     Required for devnet: patch | minor | major
# --dry-run  Print next tag without creating or pushing it

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=false
BRANCH=""
BUMP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true;  shift ;;
    --branch)  BRANCH="$2";   shift 2 ;;
    --bump)    BUMP="$2";     shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  BRANCH=$(git branch --show-current)
fi

if [[ "$BRANCH" != "devnet" && "$BRANCH" != "testnet" && "$BRANCH" != "mainnet" ]]; then
  echo "Error: branch must be devnet, testnet, or mainnet (got: '$BRANCH')" >&2
  exit 1
fi

if [[ "$BRANCH" == "devnet" ]]; then
  if [[ -z "$BUMP" ]]; then
    echo "Error: --bump patch|minor|major is required for devnet" >&2
    exit 1
  fi
  if [[ "$BUMP" != "patch" && "$BUMP" != "minor" && "$BUMP" != "major" ]]; then
    echo "Error: --bump must be patch, minor, or major (got: '$BUMP')" >&2
    exit 1
  fi
fi

echo "Branch : $BRANCH" >&2
[[ -n "$BUMP" ]] && echo "Bump   : $BUMP" >&2

# ── Helpers ───────────────────────────────────────────────────────────────────

version_gt() {
  local sorted_max
  sorted_max=$(printf '%s\n' "$1" "$2" | sort -V | tail -1)
  [[ "$sorted_max" == "$1" && "$1" != "$2" ]]
}

get_base() {
  echo "$1" | sed -E 's/^(devnet-v|testnet-v|v)//'
}

# ── Gather latest tag for each environment ────────────────────────────────────
LATEST_DEVNET_TAG=$( git tag --list 'devnet-v*'              | sort -V | tail -1)
LATEST_TESTNET_TAG=$(git tag --list 'testnet-v*'             | sort -V | tail -1)
LATEST_MAINNET_TAG=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | tail -1)

if [ -n "$LATEST_DEVNET_TAG"  ]; then DEVNET_BASE=$(get_base  "$LATEST_DEVNET_TAG");  else DEVNET_BASE="0.0.0";  fi
if [ -n "$LATEST_TESTNET_TAG" ]; then TESTNET_BASE=$(get_base "$LATEST_TESTNET_TAG"); else TESTNET_BASE="0.0.0"; fi
if [ -n "$LATEST_MAINNET_TAG" ]; then MAINNET_BASE=$(get_base "$LATEST_MAINNET_TAG"); else MAINNET_BASE="0.0.0"; fi

echo "devnet  latest : ${LATEST_DEVNET_TAG:-none}  → base $DEVNET_BASE"  >&2
echo "testnet latest : ${LATEST_TESTNET_TAG:-none} → base $TESTNET_BASE" >&2
echo "mainnet latest : ${LATEST_MAINNET_TAG:-none} → base $MAINNET_BASE" >&2
echo "---" >&2

# ── Branch-specific logic ─────────────────────────────────────────────────────
NEW_TAG=""

case "$BRANCH" in

  devnet)
    if [ -n "$LATEST_DEVNET_TAG" ]; then FROM_BASE="$DEVNET_BASE"
    elif [ -n "$LATEST_MAINNET_TAG" ]; then FROM_BASE="$MAINNET_BASE"
    else FROM_BASE="0.0.0"
    fi

    MAJOR=$(echo "$FROM_BASE" | cut -d. -f1)
    MINOR=$(echo "$FROM_BASE" | cut -d. -f2)
    PATCH=$(echo "$FROM_BASE" | cut -d. -f3)

    case "$BUMP" in
      major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
      minor) MINOR=$((MINOR+1)); PATCH=0 ;;
      patch) PATCH=$((PATCH+1)) ;;
    esac

    NEW_TAG="devnet-v${MAJOR}.${MINOR}.${PATCH}"
    ;;

  testnet)
    if version_gt "$DEVNET_BASE" "$TESTNET_BASE"; then
      echo "Promotion: devnet $DEVNET_BASE > testnet $TESTNET_BASE" >&2
      NEW_TAG="testnet-v${DEVNET_BASE}"
      BUMP="promotion"
    else
      echo "testnet is already up to date with devnet — nothing to do." >&2
      echo "${LATEST_TESTNET_TAG:-testnet-v0.0.0}"
      exit 0
    fi
    ;;

  mainnet)
    if version_gt "$TESTNET_BASE" "$MAINNET_BASE"; then
      echo "Promotion: testnet $TESTNET_BASE > mainnet $MAINNET_BASE" >&2
      NEW_TAG="v${TESTNET_BASE}"
      BUMP="promotion"
    else
      echo "mainnet is already up to date with testnet — nothing to do." >&2
      echo "${LATEST_MAINNET_TAG:-v0.0.0}"
      exit 0
    fi
    ;;
esac

# ── Idempotency: skip if tag already exists ───────────────────────────────────
if git rev-parse -q --verify "refs/tags/${NEW_TAG}" > /dev/null 2>&1; then
  echo "Tag $NEW_TAG already exists — nothing to do." >&2
  echo "$NEW_TAG"
  exit 0
fi

echo "New tag : $NEW_TAG  (bump: $BUMP)" >&2

if $DRY_RUN; then
  echo "$NEW_TAG"
  exit 0
fi

# ── Create and push the annotated tag ─────────────────────────────────────────
git tag -a "$NEW_TAG" -m "Release $NEW_TAG (bump: $BUMP)"
git push origin "$NEW_TAG"

echo "$NEW_TAG"
