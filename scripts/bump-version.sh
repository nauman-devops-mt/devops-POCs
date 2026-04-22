#!/usr/bin/env bash
# Promotion-aware semantic version bump script.
# Mirrors the logic in .github/workflows/auto-tag.yml for local use.
#
# Conventional commit rules:
#   BREAKING CHANGE (in footer) or "!:" in type → major bump
#   feat:  → minor bump
#   anything else → patch bump (default)
#
# Promotion rules:
#   testnet branch: if latest devnet tag is ahead → inherit devnet version
#   mainnet branch: if latest testnet tag is ahead → inherit testnet version
#
# Usage: ./scripts/bump-version.sh [--branch <devnet|testnet|mainnet>] [--dry-run]

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=false
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)         DRY_RUN=true; shift ;;
    --branch)          BRANCH="$2"; shift 2 ;;
    *)                 echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  BRANCH=$(git branch --show-current)
fi

if [[ "$BRANCH" != "devnet" && "$BRANCH" != "testnet" && "$BRANCH" != "mainnet" ]]; then
  echo "Error: branch must be devnet, testnet, or mainnet (got: '$BRANCH')" >&2
  exit 1
fi

echo "Branch : $BRANCH" >&2

# ── Helpers ───────────────────────────────────────────────────────────────────

version_gt() {
  local sorted_max
  sorted_max=$(printf '%s\n' "$1" "$2" | sort -V | tail -1)
  [[ "$sorted_max" == "$1" && "$1" != "$2" ]]
}

get_base() {
  echo "$1" | sed -E 's/^(devnet-v|testnet-v|v)//'
}

bump_from() {
  local base="$1" commits="$2"
  local MAJOR MINOR PATCH BUMP

  MAJOR=$(echo "$base" | cut -d. -f1)
  MINOR=$(echo "$base" | cut -d. -f2)
  PATCH=$(echo "$base" | cut -d. -f3)
  BUMP=""

  # Explicit override: #major / #minor / #patch anywhere in commit messages
  if   echo "$commits" | grep -qE '(^|[[:space:]])#major([[:space:]]|$)'; then BUMP="major"
  elif echo "$commits" | grep -qE '(^|[[:space:]])#minor([[:space:]]|$)'; then BUMP="minor"
  elif echo "$commits" | grep -qE '(^|[[:space:]])#patch([[:space:]]|$)'; then BUMP="patch"
  fi

  # Fall back to conventional commits if no explicit override found
  if [ -z "$BUMP" ]; then
    BUMP="patch"
    while IFS= read -r line; do
      if echo "$line" | grep -qiE "BREAKING[[:space:]]CHANGE"; then
        BUMP="major"; break
      fi
      if echo "$line" | grep -qE "^[a-zA-Z]+(\(.+\))?!:"; then
        BUMP="major"; break
      fi
      if echo "$line" | grep -qE "^feat(\(.+\))?:"; then
        BUMP="minor"
      fi
    done <<< "$commits"
  fi

  case "$BUMP" in
    major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR+1)); PATCH=0 ;;
    patch) PATCH=$((PATCH+1)) ;;
  esac

  echo "${BUMP}:${MAJOR}.${MINOR}.${PATCH}"
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
BUMP=""
NEW_TAG=""

case "$BRANCH" in

  devnet)
    if [ -n "$LATEST_DEVNET_TAG" ]; then
      FROM_REF="$LATEST_DEVNET_TAG";  FROM_BASE="$DEVNET_BASE"
    elif [ -n "$LATEST_MAINNET_TAG" ]; then
      FROM_REF="$LATEST_MAINNET_TAG"; FROM_BASE="$MAINNET_BASE"
    else
      FROM_REF=""; FROM_BASE="0.0.0"
    fi

    if [ -n "$FROM_REF" ]; then
      COMMITS=$(git log "${FROM_REF}..HEAD" --pretty=format:"%s%n%b")
    else
      COMMITS=$(git log --pretty=format:"%s%n%b")
    fi

    if [ -z "$COMMITS" ]; then
      echo "No new commits since ${FROM_REF:-start} — nothing to do." >&2
      echo "${LATEST_DEVNET_TAG:-devnet-v0.0.0}"
      exit 0
    fi

    _result=$(bump_from "$FROM_BASE" "$COMMITS"); BUMP="${_result%%:*}"; NEW_BASE="${_result#*:}"
    NEW_TAG="devnet-v${NEW_BASE}"
    ;;

  testnet)
    if version_gt "$DEVNET_BASE" "$TESTNET_BASE"; then
      echo "Promotion: devnet $DEVNET_BASE > testnet $TESTNET_BASE" >&2
      NEW_TAG="testnet-v${DEVNET_BASE}"
      BUMP="promotion"
    else
      if [ -n "$LATEST_TESTNET_TAG" ]; then
        FROM_REF="$LATEST_TESTNET_TAG";  FROM_BASE="$TESTNET_BASE"
      elif [ -n "$LATEST_MAINNET_TAG" ]; then
        FROM_REF="$LATEST_MAINNET_TAG"; FROM_BASE="$MAINNET_BASE"
      else
        FROM_REF=""; FROM_BASE="0.0.0"
      fi

      if [ -n "$FROM_REF" ]; then
        COMMITS=$(git log "${FROM_REF}..HEAD" --pretty=format:"%s%n%b")
      else
        COMMITS=$(git log --pretty=format:"%s%n%b")
      fi

      if [ -z "$COMMITS" ]; then
        echo "No new commits since ${FROM_REF:-start} — nothing to do." >&2
        echo "${LATEST_TESTNET_TAG:-testnet-v0.0.0}"
        exit 0
      fi

      _result=$(bump_from "$FROM_BASE" "$COMMITS"); BUMP="${_result%%:*}"; NEW_BASE="${_result#*:}"
      NEW_TAG="testnet-v${NEW_BASE}"
    fi
    ;;

  mainnet)
    if version_gt "$TESTNET_BASE" "$MAINNET_BASE"; then
      echo "Promotion: testnet $TESTNET_BASE > mainnet $MAINNET_BASE" >&2
      NEW_TAG="v${TESTNET_BASE}"
      BUMP="promotion"
    else
      if [ -n "$LATEST_MAINNET_TAG" ]; then
        FROM_REF="$LATEST_MAINNET_TAG"; FROM_BASE="$MAINNET_BASE"
      else
        FROM_REF=""; FROM_BASE="0.0.0"
      fi

      if [ -n "$FROM_REF" ]; then
        COMMITS=$(git log "${FROM_REF}..HEAD" --pretty=format:"%s%n%b")
      else
        COMMITS=$(git log --pretty=format:"%s%n%b")
      fi

      if [ -z "$COMMITS" ]; then
        echo "No new commits since ${FROM_REF:-start} — nothing to do." >&2
        echo "${LATEST_MAINNET_TAG:-v0.0.0}"
        exit 0
      fi

      _result=$(bump_from "$FROM_BASE" "$COMMITS"); BUMP="${_result%%:*}"; NEW_BASE="${_result#*:}"
      NEW_TAG="v${NEW_BASE}"
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
