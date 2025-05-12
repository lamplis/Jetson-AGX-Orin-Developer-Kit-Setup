#!/usr/bin/env bash
#───────────────────────────────────────────────────────────────
# build_llvm_deb.sh
#
# Build LLVM + MLIR from source (AArch64 native) and package as a .deb
# Output: $HOME/debs/llvm-aarch64-<version>.deb
#
# Tested on JetPack 6.x (Ubuntu 22.04, CUDA 12.6)
#───────────────────────────────────────────────────────────────

set -euo pipefail

#────────────── Config
NPROC=$(nproc)
VERSION="17.0.6"
PACKAGE_NAME="llvm-aarch64"
SRC_DIR="$HOME/Workspace/sources/llvm"
BUILD_DIR="$HOME/Workspace/builds/llvm-build"
INSTALL_DIR="$HOME/.triton/llvm-aarch64"
DEB_OUTPUT_DIR="$HOME/debs"

#────────────── Prepare
rm -rf "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR" "$DEB_OUTPUT_DIR"

echo "📥 Cloning LLVM source…"
git clone --depth 1 --branch "llvmorg-$VERSION" https://github.com/llvm/llvm-project.git "$SRC_DIR"

#────────────── Configure with CMake + CPack for .deb
echo "⚙️  Configuring CMake with packaging options…"
cmake -G Ninja \
  -S "$SRC_DIR/llvm" \
  -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="mlir" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;ARM;NVPTX" \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCPACK_GENERATOR="DEB" \
  -DCPACK_PACKAGE_NAME="$PACKAGE_NAME" \
  -DCPACK_PACKAGE_VERSION="$VERSION" \
  -DCPACK_PACKAGE_FILE_NAME="${PACKAGE_NAME}-${VERSION}" \
  -DCPACK_PACKAGING_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCPACK_DEBIAN_PACKAGE_MAINTAINER="lamplis <lamplis@yahoo.fr>" \
  -DCPACK_DEBIAN_COMPRESSION_TYPE="xz" \
  -DCPACK_SET_DESTDIR=OFF

echo "🔨 Building LLVM ($NPROC threads)…"
cmake --build "$BUILD_DIR" -j"$NPROC"

echo "📦 Installing locally to: $INSTALL_DIR"
cmake --install "$BUILD_DIR"

#────────────── Generate .deb package
echo "📦 Creating .deb package with CPack…"
pushd "$BUILD_DIR"
cpack -G DEB
popd

#────────────── Move final .deb to deb output dir
echo "📁 Moving .deb package to: $DEB_OUTPUT_DIR"
find "$BUILD_DIR" -name "${PACKAGE_NAME}*.deb" -exec mv -v {} "$DEB_OUTPUT_DIR/" \;

echo "✅ Done: LLVM .deb available in $DEB_OUTPUT_DIR"

