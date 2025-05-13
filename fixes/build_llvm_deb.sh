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

#────────────────────── Parse arguments
NO_CACHE=false
for arg in "$@"; do
  case $arg in
    --no-cache)
      NO_CACHE=true
      shift
      ;;
    *)
      echo "❌ Unknown option: $arg"
      exit 1
      ;;
  esac
done

#────────────────────── Configuration
NPROC=$(nproc)
VERSION="17.0.6"
PACKAGE_NAME="llvm-aarch64"
SRC_DIR="$HOME/Workspace/sources/llvm"
BUILD_DIR="$HOME/Workspace/builds/llvm-build"
INSTALL_DIR="$HOME/.triton/llvm-aarch64"
DEB_OUTPUT_DIR="$HOME/debs"

#────────────────────── Manage cache
if $NO_CACHE; then
  echo "🧹 Full cleanup (--no-cache)"
  rm -rf "$SRC_DIR" "$BUILD_DIR"
  if [[ -d "$INSTALL_DIR" ]]; then
    echo "⚠️  $INSTALL_DIR already exists, attempting to remove with sudo..."
    sudo rm -rf "$INSTALL_DIR"
  fi
fi

mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR" "$DEB_OUTPUT_DIR"

#────────────────────── Clone LLVM sources if missing
if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "📥 Cloning LLVM source..."
  git clone --depth 1 --branch "llvmorg-$VERSION" https://github.com/llvm/llvm-project.git "$SRC_DIR"
else
  echo "✅ LLVM sources already present (cache enabled)"
fi

#────────────────────── Patch CMP0175 and COMMENT lines in Tooling CMakeLists.txt
TOOLING_CMAKE="$SRC_DIR/clang/lib/Tooling/CMakeLists.txt"
if [[ -f "$TOOLING_CMAKE" ]]; then
  echo "🛠️  Patching COMMENT lines & CMP0175 in Tooling/CMakeLists.txt"

  # 1) Wrap any COMMENT text that is not already quoted
  sed -Ei.bak \
    -e '/^[[:space:]]*COMMENT[[:space:]]+[^"]/{s/COMMENT[[:space:]]+(.*)$/COMMENT "\1"/}' \
    -e 's/COMMENT[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"/COMMENT "\1 \2"/g' \
    -e 's/COMMENT[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"/COMMENT "\1 \2 \3"/g' \
    -e 's/COMMENT[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"/COMMENT "\1 \2 \3 \4"/g' \
    "$TOOLING_CMAKE"
  
  # 2) Ensure CMP0175 is NEW
  grep -q "cmake_policy(SET CMP0175 NEW)" "$TOOLING_CMAKE" || \
    sed -i '1i cmake_policy(SET CMP0175 NEW)\n' "$TOOLING_CMAKE"
else
  echo "⚠️  Tooling CMakeLists.txt not found – patch skipped"
fi
#──────── (Optional) silence CMP0116 top‑level
ROOT_CMAKE="$SRC_DIR/llvm/CMakeLists.txt"
grep -q CMP0116 "$ROOT_CMAKE" || sed -i '1i cmake_policy(SET CMP0116 NEW)\n' "$ROOT_CMAKE"

#────────────────────── CMake configuration with packaging
echo "⚙️  Configuring CMake with packaging options..."
  #-DLLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;compiler-rt;lld;lldb;mlir;openmp;polly;pstl;flang" \  

cmake -G Ninja \
  -S "$SRC_DIR/llvm" \
  -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="mlir;clang;lld" \
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

#────────────────────── Build and install
echo "🔨 Building LLVM ($NPROC threads)..."
cmake --build "$BUILD_DIR" -j"$NPROC"

echo "📦 Installing to: $INSTALL_DIR"
cmake --install "$BUILD_DIR" --strip

#────────────────────── Dumping CMake error log

echo "🧾 Dumping CMake error log:"
cat "$BUILD_DIR/CMakeFiles/CMakeError.log" || echo "(no error log found)"

#────────────────────── Auto-detect runtime dependencies
echo "🔍 Analyzing installed binary dependencies..."
BINARIES=$(find "$INSTALL_DIR/bin" -type f -executable)
DEPS_RAW=$(for bin in $BINARIES; do ldd "$bin" 2>/dev/null; done | awk '{print $1}' | grep '\.so' | sort -u)

echo "📦 Detected shared libraries:"
DEB_PKGS=()
for lib in $DEPS_RAW; do
    path=$(ldconfig -p | grep "$lib" | awk '{print $NF}' | head -n1)
    if [[ -n "$path" ]]; then
        pkg=$(dpkg -S "$path" 2>/dev/null | cut -d: -f1 | head -n1)
        if [[ -n "$pkg" ]]; then
            echo "  • $lib → $pkg"
            DEB_PKGS+=("$pkg")
        fi
    fi
done

# Deduplicate dependencies
DEB_PKGS_UNIQUE=$(echo "${DEB_PKGS[@]}" | tr ' ' '
' | sort -u | tr '
' ',' | sed 's/,\$//')

if [[ -n "$DEB_PKGS_UNIQUE" ]]; then
  echo ""
  echo "📌 Writing CPack dependency patch:"
  echo "set(CPACK_DEBIAN_PACKAGE_DEPENDS "$DEB_PKGS_UNIQUE")" > "$BUILD_DIR/dependencies.cmake"
else
  echo "⚠️ No dependencies detected automatically."
fi

#────────────────────── Patch CPack config
echo "📦 Injecting dependencies into CPackConfig.cmake..."
if [[ -f "$BUILD_DIR/dependencies.cmake" ]]; then
  if ! grep -q 'include("${CMAKE_CURRENT_LIST_DIR}/dependencies.cmake")' "$BUILD_DIR/CPackConfig.cmake"; then
    echo 'include("${CMAKE_CURRENT_LIST_DIR}/dependencies.cmake")' >> "$BUILD_DIR/CPackConfig.cmake"
    echo "✅ Patched: dependencies.cmake included"
  else
    echo "ℹ️ Patch already present in CPackConfig.cmake"
  fi
else
  echo "⚠️ Warning: dependencies.cmake not found"
fi

#────────────────────── Create .deb package
echo "📦 Creating .deb package with CPack..."
pushd "$BUILD_DIR"
cpack -G DEB
popd

#────────────────────── Move .deb to output folder
echo "📁 Moving .deb package to: $DEB_OUTPUT_DIR"
find "$BUILD_DIR" -name "${PACKAGE_NAME}*.deb" -exec mv -v {} "$DEB_OUTPUT_DIR/" \;

echo "✅ Done: LLVM .deb available in $DEB_OUTPUT_DIR"

#────────────────────── Check key binaries
LLVM_DIR="$INSTALL_DIR"
echo "🔍 Verifying key installed binaries..."
check_binary() {
  local bin="$1"
  if [[ -x "$LLVM_DIR/bin/$bin" ]]; then
    echo "✅ $bin found"
    file "$LLVM_DIR/bin/$bin" | grep -q "ARM aarch64"       && echo "   ✅ Architecture: AArch64"       || echo "   ❌ Wrong architecture"
  else
    echo "❌ $bin not found or not executable"
  fi
}
check_binary clang
check_binary mlir-tblgen
check_binary opt
check_binary llc
echo "✔️  Binary verification complete."
