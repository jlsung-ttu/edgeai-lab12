#!/usr/bin/env bash
set -e
echo "=== Step 0 validator: repo plumbing ==="

gh auth status >/dev/null 2>&1 || { echo "FAIL: gh not authenticated."; exit 1; }
echo "PASS: gh authenticated"

ORIGIN=$(git remote get-url origin)
[[ "$ORIGIN" == *github.com* ]] || { echo "FAIL: origin is not github.com: $ORIGIN"; exit 1; }
echo "PASS: origin = $ORIGIN"

VIS=$(gh repo view --json visibility --jq .visibility)
[[ "$VIS" == "PUBLIC" ]] || { echo "FAIL: repo visibility is $VIS, must be PUBLIC"; exit 1; }
echo "PASS: repo is PUBLIC"

for f in Dockerfile.ci inference_node.py requirements.txt best.pt pyproject.toml pdm.lock; do
  git cat-file -e "HEAD:$f" 2>/dev/null || { echo "FAIL: $f missing from HEAD"; exit 1; }
  echo "PASS: $f present"
done

echo "=== Step 0 PASS ==="
