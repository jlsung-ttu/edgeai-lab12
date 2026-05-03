#!/usr/bin/env bash
# validate_step2.sh — confirm the GPU-dependent compile is no longer in
# the Dockerfile build, and entrypoint.sh exists and is executable.
set -e
echo "=== Step 2 validator: build is GPU-independent ==="

# 1. No engine compile in any RUN line of Dockerfile.ci
if grep -E '^\s*RUN' Dockerfile.ci | grep -qE 'format[ =][\x27"]?engine'; then
    echo "FAIL: Dockerfile.ci still has a build-time engine compile in a RUN line"
    grep -nE '^\s*RUN' Dockerfile.ci | grep -E 'format[ =][\x27"]?engine'
    exit 1
fi
echo "PASS: no build-time engine compile in Dockerfile.ci"

# 2. entrypoint.sh exists, is executable, and has the right shebang
[ -f entrypoint.sh ] || { echo "FAIL: entrypoint.sh missing"; exit 1; }
[ -x entrypoint.sh ] || { echo "FAIL: entrypoint.sh not executable"; exit 1; }
HEAD=$(head -1 entrypoint.sh)
[[ "$HEAD" == "#!/usr/bin/env bash" || "$HEAD" == "#!/bin/bash" ]] || {
    echo "FAIL: entrypoint.sh wrong shebang: $HEAD"; exit 1
}
echo "PASS: entrypoint.sh exists, executable, valid shebang"

# 3. entrypoint.sh actually does the engine compile
grep -q "format=engine\|format='engine'\|format=\"engine\"" entrypoint.sh || {
    echo "FAIL: entrypoint.sh does not contain format=engine"; exit 1
}
echo "PASS: entrypoint.sh contains the deferred engine compile"

# 4. Dockerfile.ci wires entrypoint.sh in
grep -q "ENTRYPOINT.*entrypoint.sh" Dockerfile.ci || {
    echo "FAIL: Dockerfile.ci has no ENTRYPOINT pointing at entrypoint.sh"; exit 1
}
echo "PASS: Dockerfile.ci wires up entrypoint.sh as ENTRYPOINT"

echo "=== Step 2 PASS ==="
