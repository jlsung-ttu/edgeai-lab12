#!/usr/bin/env bash
# entrypoint.sh — runtime startup for the Lab 12 inference container.
#
# Why this exists:
#   The TensorRT engine compile (yolo export format=engine) needs a real
#   GPU. We can't run it during `docker build` because the build happens
#   on a GitHub-hosted x86 runner under QEMU ARM64 emulation, where no
#   GPU is exposed. Instead we defer the compile until the first time
#   the container actually starts on the Jetson.
#
# What it does:
#   1. If best.engine is missing in /opt/models, compile it from best.pt
#      (one-time, ~5-8 min).
#   2. exec the CMD passed by Docker (default: python3 inference_node.py).
#
# Caching:
#   /opt/models is the canonical location. To avoid re-compiling on every
#   container restart, mount /opt/models from a host volume:
#     docker run -v /opt/edgeai/models:/opt/models ...
#   The first container build compiles the engine; subsequent containers
#   on the same host see best.engine and skip the compile.
set -euo pipefail

MODEL_DIR=/opt/models
ENGINE_FILE="${MODEL_DIR}/best.engine"
WEIGHTS_FILE="${MODEL_DIR}/best.pt"

if [ ! -f "$ENGINE_FILE" ]; then
    if [ ! -f "$WEIGHTS_FILE" ]; then
        echo "ERROR: $WEIGHTS_FILE not found. Image build is broken." >&2
        exit 1
    fi
    echo "[entrypoint] First start: compiling TensorRT engine (one-time, ~5-8 min)..."
    cd "$MODEL_DIR"
    python3 -c "from ultralytics import YOLO; YOLO('best.pt', task='detect').export(format='engine', imgsz=320, half=True, opset=19)"
    echo "[entrypoint] Engine compiled: $ENGINE_FILE"
else
    echo "[entrypoint] Cached engine found at $ENGINE_FILE — skipping compile."
fi

# Hand off to whatever CMD the image specifies (default: inference_node.py)
exec "$@"
