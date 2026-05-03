#!/usr/bin/env bash
# validate_step3.sh — verify the most recent workflow run produced a
# linux/arm64 image in GHCR with the current commit's short SHA tag.

set -e
echo "=== Step 3 validator: ARM64 image in GHCR ==="

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
SHA=$(git rev-parse --short HEAD)
OWNER=$(echo "$REPO" | cut -d/ -f1)
PKG=$(echo "$REPO" | cut -d/ -f2)
IMAGE="ghcr.io/$REPO"

echo "Looking for $IMAGE:sha-$SHA"

# 1. Wait for the build job to finish (up to 50 min)
for i in {1..600}; do
  STATUS=$(gh run list --workflow=ci.yml --limit 1 --json status,conclusion --jq '.[0]')
  S=$(echo "$STATUS" | jq -r .status)
  C=$(echo "$STATUS" | jq -r .conclusion)
  if [ "$S" = "completed" ]; then
    [ "$C" = "success" ] || { echo "FAIL: workflow conclusion=$C"; exit 1; }
    echo "PASS: workflow completed successfully"
    break
  fi
  [ $((i % 12)) -eq 0 ] && echo "  ...$((i*5/60)) min elapsed, status=$S"
  sleep 5
done

# 2. Check the package exists in GHCR
OWNER_TYPE=$(gh api "/users/$OWNER" --jq .type 2>/dev/null || echo "User")
if [ "$OWNER_TYPE" = "Organization" ]; then
  PKG_PATH="/orgs/$OWNER/packages/container/$PKG/versions"
else
  PKG_PATH="/users/$OWNER/packages/container/$PKG/versions"
fi

gh api "$PKG_PATH" --jq '.[0].metadata.container.tags' \
  > /tmp/tags.json 2>/dev/null \
  || { echo "FAIL: cannot read GHCR package metadata at $PKG_PATH"; exit 1; }

if grep -q "sha-$SHA" /tmp/tags.json; then
    echo "PASS: image tagged sha-$SHA found in GHCR"
else
    echo "FAIL: sha-$SHA not in package tags. Got:"
    cat /tmp/tags.json
    exit 1
fi

echo "=== Step 3 PASS ==="
