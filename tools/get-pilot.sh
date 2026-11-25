#!/usr/bin/env bash
# Download the OMG SysML v2 pilot implementation (Jupyter kernel build,
# from conda-forge) into .pilot/ and print the SYSML_PILOT path to use.
# Needs: curl, unzip, python3 with the 'zstandard' package.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${SYSML_PILOT_VERSION:-0.63.1}"
PKG="jupyter-sysml-kernel-${VERSION}-pyhd8ed1ab_0.conda"
DEST=".pilot/${VERSION}"
if [ ! -f "$DEST/share/jupyter/kernels/sysml/jupyter-sysml-kernel-${VERSION}-all.jar" ]; then
  mkdir -p "$DEST/tmp"
  curl -fsSL -o "$DEST/tmp/$PKG" "https://conda.anaconda.org/conda-forge/noarch/$PKG"
  (cd "$DEST/tmp" && unzip -o -q "$PKG")
  python3 - "$DEST" <<'PY'
import glob, sys, tarfile, zstandard
dest = sys.argv[1]
for f in glob.glob(f"{dest}/tmp/pkg-*.tar.zst"):
    with open(f, "rb") as fh, zstandard.ZstdDecompressor().stream_reader(fh) as r:
        tarfile.open(fileobj=r, mode="r|").extractall(dest, filter="data")
PY
  rm -rf "$DEST/tmp"
fi
echo "$(pwd)/$DEST/share/jupyter/kernels/sysml"
