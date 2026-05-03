#!/usr/bin/env bash
# entrypoint.sh — runs at container start on the Jetson.
#
# What it does:
#   1. If best.engine is missing or older than best.pt, compile it with
#      Ultralytics' yolo export. This needs the GPU (--runtime nvidia)
#      and uses the container's TensorRT 10.3.
#   2. exec inference_node.py so signals (SIGTERM from `docker stop`)
#      are delivered to the Python process, not to bash.
#
# Why deferred to runtime instead of `RUN` in the Dockerfile?
#   QEMU emulation on the GitHub-hosted x86 runner can fake aarch64
#   instructions but cannot present a CUDA device, so `yolo export
#   format=engine` would fail at build time. Running it at container
#   start on the Jetson sidesteps the issue and matches production
#   practice — engines are host-specific anyway (driver/TRT version
#   on the build host must match the run host, so binding the compile
#   to first run guarantees they match).
#
# First run takes 5–8 min. Mount /opt/models as a volume so subsequent
# runs reuse the cached engine:
#   docker run -v lab12-models:/opt/models ...

set -euo pipefail

MODEL_DIR=/opt/models
WEIGHTS=${MODEL_DIR}/best.pt
ENGINE=${MODEL_DIR}/best.engine

if [ ! -f "${WEIGHTS}" ]; then
  echo "ERROR: ${WEIGHTS} not found. Did you copy best.pt into the image?" >&2
  exit 1
fi

# Recompile if engine is missing or older than weights
if [ ! -f "${ENGINE}" ] || [ "${WEIGHTS}" -nt "${ENGINE}" ]; then
  echo "[entrypoint] Compiling TensorRT engine (this takes 5–8 min on first boot)..."
  cd "${MODEL_DIR}"
  python3 -c "
from ultralytics import YOLO
YOLO('best.pt', task='detect').export(format='engine', imgsz=320, half=True, opset=19)
"
  echo "[entrypoint] Engine compiled: $(ls -lh ${ENGINE} | awk '{print $5}')"
else
  echo "[entrypoint] Reusing cached engine: $(ls -lh ${ENGINE} | awk '{print $5}')"
fi

# exec replaces the bash process so docker stop sends SIGTERM directly
# to Python, which lets graceful-shutdown handlers in inference_node.py
# actually run.
exec python3 /app/inference_node.py "$@"
