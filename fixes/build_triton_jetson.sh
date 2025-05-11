#!/usr/bin/env bash
#───────────────────────────────────────────────────────────────
# build_triton_jetson.sh
#
# Build LLVM + MLIR (aarch64 native) and Triton 2.1.0,
# then produce a wheel in $HOME/wheels/triton-wheel.
#
# Tested on JetPack 6 (CUDA 12.6, Ubuntu 22.04, Python 3.10).
# Runtime: ~90 min on Orin 64 GB; needs ≈ 14 GB RAM + 25 GB disk.
#───────────────────────────────────────────────────────────────
set -euo pipefail
NPROC=$(nproc)

#──────────────────────── paths
ROOT="$PWD"
WHEEL_DIR="$HOME/wheels/triton-wheel"
LLVM_DEB_SCRIPT="$HOME/Workspace/Pinokio/build_llvm_deb.sh"
LLVM_DEB_FILE=$(find "$HOME/debs" -name 'llvm-aarch64-*.deb' | head -n1 || true)
LLVM_INSTALL_DIR="$HOME/.triton/llvm-aarch64"
LLVM_SRC="$HOME/Workspace/sources/llvm"
LLVM_BUILD="$HOME/Workspace/builds/llvm-build"
TRITON_SRC="$HOME/Workspace/sources/triton"

mkdir -p "$WHEEL_DIR"

#──────────────────────── deps (Ubuntu)
sudo apt-get update
sudo apt-get install -y build-essential ninja-build git cmake \
        python3-dev python3-venv python3-setuptools python3-wheel \
        libffi-dev wget curl

#──────────────────────── 1. Install LLVM via .deb package
if [[ ! -f "$LLVM_DEB_FILE" ]]; then
  echo "🚧  LLVM/MLIR deb not found, building via build_llvm_deb.sh…"
  bash "$LLVM_DEB_SCRIPT"
  LLVM_DEB_FILE=$(find "$HOME/debs" -name 'llvm-aarch64-*.deb' | head -n1)
else
  echo "📦  Found existing LLVM deb: $LLVM_DEB_FILE"
fi

echo "📥  Installing LLVM deb: $LLVM_DEB_FILE"
sudo dpkg -i "$LLVM_DEB_FILE"

# Set environment for Triton build
export TRITON_USE_CUSTOM_LLVM=1
export LLVM_DIR="$LLVM_INSTALL_DIR"
export PATH="$LLVM_DIR/bin:$PATH"
export CMAKE_PREFIX_PATH="$LLVM_DIR:$CMAKE_PREFIX_PATH"

#──────────────────────── 2. Clone Triton 2.1.0 (OpenAI archive)
echo "🚧  Cloning Triton 2.1.0 (OpenAI archive)…"
rm -rf "$TRITON_SRC"
git clone --recursive https://github.com/triton-lang/triton.git "$TRITON_SRC"
pushd "$TRITON_SRC"
# Last commit tagged 2.1.0 by OpenAI (pre‑migration)
git checkout v2.1.0          # ← change ici
git submodule update --init --recursive
popd

#──────────────────────── 3. Patch setup.py (skip ptxas download)
echo "🔧  Patching setup.py to disable ptxas/LLVM downloads…"
sed -i '/def # download_and_copy_ptxas/ d' "$TRITON_SRC/python/setup.py"
sed -i 's/^\(\s*\)download_and_copy_ptxas(/# \1download_and_copy_ptxas(/' "$TRITON_SRC/python/setup.py"
sed -i 's/^\(\s*\)download_and_extract_llvm(/# \1download_and_extract_llvm(/' "$TRITON_SRC/python/setup.py"

# Ensure Triton uses JetPack’s ptxas
mkdir -p "$TRITON_SRC/python/triton/third_party/cuda/bin"
ln -sf /usr/local/cuda/bin/ptxas \
      "$TRITON_SRC/python/triton/third_party/cuda/bin/ptxas"

#──────────────────────── 4. Build Triton wheel
echo "🏗️   Building Triton wheel…"
pip install -U pip setuptools wheel cmake ninja pybind11 lit
pushd "$TRITON_SRC/python"
python -m pip wheel . -w "$WHEEL_DIR" --no-build-isolation --no-deps
popd

echo "✅  Wheel ready:"
ls -lh "$WHEEL_DIR" | grep triton

echo -e "\n👉  Install with:"
echo "    pip install $WHEEL_DIR/$(ls $WHEEL_DIR | grep triton | head -n1)"

