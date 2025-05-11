#!/bin/bash
set -e

#───────────────────────────────────────────────────────────────────────────────
# Build and package LLVM + MLIR as .deb for ARM64 (Jetson)
#───────────────────────────────────────────────────────────────────────────────

# Define key paths
SRC_DIR="$HOME/Workspace/sources/llvm"
BUILD_DIR="$HOME/Workspace/builds/llvm-build"
INSTALL_DIR="$HOME/Workspace/builds/llvm-install"
DEB_OUT_DIR="$HOME/debs"

# Ensure output directories exist
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR" "$DEB_OUT_DIR"

# Clone LLVM monorepo with MLIR if not already present
if [ ! -d "$SRC_DIR" ]; then
  echo "📥 Cloning LLVM monorepo..."
  git clone https://github.com/llvm/llvm-project.git "$SRC_DIR"
fi

# Configure CMake build
echo "🛠️  Configuring LLVM build with MLIR..."
cmake -S "$SRC_DIR/llvm" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DLLVM_ENABLE_PROJECTS="mlir;clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="AArch64" \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_INSTALL_UTILS=ON \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DMLIR_ENABLE_BINDINGS_PYTHON=OFF \
  -DCMAKE_EXPORT_PACKAGE_REGISTRY=OFF \
  -G Ninja

# Build all targets with all available CPU cores
echo "🔨 Building LLVM+MLIR with $(nproc) threads..."
cmake --build "$BUILD_DIR" --parallel $(nproc)

# Optional local install
echo "📦 Installing to $INSTALL_DIR..."
cmake --install "$BUILD_DIR"

# Build Debian package
echo "📦 Creating .deb package..."
cmake --build "$BUILD_DIR" --target package

# Move generated .deb packages to output directory
echo "📁 Moving .deb packages to $DEB_OUT_DIR"
find "$BUILD_DIR" -type f -name "*.deb" -exec mv {} "$DEB_OUT_DIR" \;

echo "✅ Done: .deb files available in $DEB_OUT_DIR"

