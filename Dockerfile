ARG BASE_IMAGE=nvcr.io/nvidia/quantum/cuda-quantum@sha256:10764a9a7bfbe8d201967e493cfe238a9c599ef03efd183367163ff6092e4bd7
FROM ${BASE_IMAGE}

ARG BOOTSTRAP_SHA256=0d0156d915f7b9473518e2893983cbd1ff6c1dfa7824e984239ec9f58192308a

# The upstream CUDA-Q image runs as an unprivileged user. Package installation
# is confined to this immutable image-build layer; the resulting worker must
# run as root so it can initialize host keys and sshd on a fresh Pod.
USER root

# Packages are installed only during the immutable build, never at worker
# startup while a rental is billing.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server iproute2 procps ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && install -d -m 0755 /run/sshd /usr/local/share/benchmark

COPY --chmod=0755 pod-ssh-bootstrap.sh /usr/local/sbin/pod-ssh-bootstrap.sh
COPY --chmod=0755 rental-entrypoint.sh /usr/local/sbin/rental-entrypoint.sh
COPY --chmod=0755 rental-job-anchor.py /usr/local/sbin/rental-job-anchor.py

RUN printf '%s  %s\n' "${BOOTSTRAP_SHA256}" /usr/local/sbin/pod-ssh-bootstrap.sh | sha256sum -c - \
    && command -v /usr/sbin/sshd >/dev/null \
    && command -v /usr/bin/ssh-keygen >/dev/null \
    && /usr/bin/ssh-keygen -A \
    && /usr/sbin/sshd -t \
    && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && python3 - <<'PY'
import importlib.metadata as metadata
import json
import os
import platform

cudaq = metadata.version("cuda-quantum")
if not cudaq.startswith("0.16.0"):
    raise SystemExit(f"CUDA-Q drift: {cudaq}")
if not platform.python_version().startswith("3.12."):
    raise SystemExit(f"Python drift: {platform.python_version()}")
if os.environ.get("CUDA_VERSION") != "13.0":
    raise SystemExit(f"CUDA drift: {os.environ.get('CUDA_VERSION')}")
packages = {}
for name in ("cuda-quantum", "cuquantum-python-cu13", "cuquantum-cu13", "cupy-cuda13x", "numpy"):
    try:
        packages[name] = metadata.version(name)
    except metadata.PackageNotFoundError:
        packages[name] = None
with open("/usr/local/share/benchmark/runtime-matrix.json", "w", encoding="utf-8") as handle:
    json.dump({"python": platform.python_version(), "cuda": os.environ["CUDA_VERSION"], "packages": packages}, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

LABEL org.opencontainers.image.title="Neutral CUDA-Q worker" \
      org.opencontainers.image.description="Digest-locked CUDA-Q 0.16.0 CUDA 13 runtime with managed SSH" \
      benchmark.runtime.profile="cudaq-0.16.0-cu130-ssh-v1" \
      benchmark.runtime.cudaq="0.16.0" \
      benchmark.runtime.cuda="13.0" \
      benchmark.runtime.startup-package-installation="false" \
      benchmark.ssh.bootstrap.sha256="0d0156d915f7b9473518e2893983cbd1ff6c1dfa7824e984239ec9f58192308a"

ENTRYPOINT ["/usr/local/sbin/rental-entrypoint.sh"]
CMD ["__LIVE_ARGS_REQUIRED__"]
