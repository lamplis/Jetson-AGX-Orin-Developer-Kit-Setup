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

#──────── Clean when --no-cache
if $NO_CACHE; then
  echo "🧹 Removing previous build (--no-cache)"
  rm -rf "$SRC_DIR" "$BUILD_DIR"
  [[ -d "$INSTALL_DIR" ]] && sudo rm -rf "$INSTALL_DIR"
fi
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR" "$DEB_OUTPUT_DIR"

#──────── Clone if missing
if [[ ! -d "$SRC_DIR/.git" ]]; then
  git clone --depth 1 --branch "llvmorg-$VERSION" https://github.com/llvm/llvm-project.git "$SRC_DIR"
else
  echo "✅ LLVM sources already present (cache)"
fi

#──────── Patch Tooling/CMakeLists.txt
TOOLING_CMAKE="$SRC_DIR/clang/lib/Tooling/CMakeLists.txt"
if [[ -f "$TOOLING_CMAKE" ]]; then
  echo "🛠️  Patching COMMENT & CMP0175"
  sed -Ei.bak '
    /^[[:space:]]*COMMENT[[:space:]]+[^"]/{s/COMMENT[[:space:]]+(.*)$/COMMENT "\1"/}
    s/COMMENT[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"/COMMENT "\1 \2"/g
    s/COMMENT[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"[[:space:]]+"([^"]+)"/COMMENT "\1 \2 \3"/g
  ' "$TOOLING_CMAKE"
  grep -q CMP0175 "$TOOLING_CMAKE" || sed -i '1i cmake_policy(SET CMP0175 NEW)\n' "$TOOLING_CMAKE"
fi

#──────── Optional: silence CMP0116
ROOT_CMAKE="$SRC_DIR/llvm/CMakeLists.txt"
[[ -f "$ROOT_CMAKE" ]] && grep -q CMP0116 "$ROOT_CMAKE" || sed -i '1i cmake_policy(SET CMP0116 NEW)\n' "$ROOT_CMAKE"

#──────── Configure
cmake -G Ninja \
  -S "$SRC_DIR/llvm" \
  -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="mlir;clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;ARM;NVPTX" \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCPACK_GENERATOR="DEB" \
  -DCPACK_PACKAGE_NAME="$PACKAGE_NAME" \
  -DCPACK_PACKAGE_VERSION="$VERSION" \
  -DCPACK_PACKAGE_FILE_NAME="${PACKAGE_NAME}-${VERSION}" \
  -DCPACK_PACKAGING_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCPACK_DEBIAN_PACKAGE_MAINTAINER="lamplis <lamplis@yahoo.fr>" \
  -DCPACK_DEBIAN_COMPRESSION_TYPE="xz" \
  -DCPACK_INCLUDE_TOPLEVEL_DIRECTORY=OFF \
  -DCPACK_SET_DESTDIR=OFF

#──────── Build & install (stripped)
cmake --build "$BUILD_DIR" -j"$NPROC"
cmake --install "$BUILD_DIR" --strip

#──────── Dump any CMake error log (for debug)
echo "🧾 Dumping CMake error log:"
cat "$BUILD_DIR/CMakeFiles/CMakeError.log" 2>/dev/null || echo "(no error log found)"

#──────── Auto-detect runtime dependencies
echo "🔍 Scanning runtime dependencies..."
BINARIES=$(find "$INSTALL_DIR/bin" -type f -executable)
LIBS=$(for b in $BINARIES; do ldd "$b" 2>/dev/null; done | awk '{print $1}' | grep '\.so' | sort -u)
PKGS=()
for l in $LIBS; do
  f=$(ldconfig -p | grep "$l" | awk '{print $NF}' | head -n1)
  [[ $f ]] && p=$(dpkg -S "$f" 2>/dev/null | cut -d: -f1 | head -n1) && [[ $p ]] && PKGS+=("$p")
done
UNIQUE=$(printf '%s\n' "${PKGS[@]}" | sort -u | paste -sd, -)
if [[ $UNIQUE ]]; then
  echo "set(CPACK_DEBIAN_PACKAGE_DEPENDS \"${UNIQUE}\")" > "$BUILD_DIR/dependencies.cmake"
  grep -q dependencies.cmake "$BUILD_DIR/CPackConfig.cmake" || \
  echo 'include("${CMAKE_CURRENT_LIST_DIR}/dependencies.cmake")' >> "$BUILD_DIR/CPackConfig.cmake"
fi

#──────── Create .deb
echo "📦 Running CPack..."
pushd "$BUILD_DIR" >/dev/null
cpack --config CPackConfig.cmake -G DEB --verbose
popd >/dev/null

# Fail if no deb produced
if ! find "$BUILD_DIR" -name "${PACKAGE_NAME}*.deb" | grep -q .; then
  echo "❌ CPack completed but no .deb package was produced. Check output above."
  exit 1
fi

#──────── Move .deb out
echo "📁 Moving .deb to $DEB_OUTPUT_DIR"
find "$BUILD_DIR" -name "${PACKAGE_NAME}*.deb" -exec mv -v {} "$DEB_OUTPUT_DIR/" \;

echo "✅ Finished — .deb is in $DEB_OUTPUT_DIR"

#────────────────────── Check key binaries
LLVM_DIR="$INSTALL_DIR"
echo "🔍 Verifying key installed binaries..."
check_binary() {
  local bin="$1"
  local f="$LLVM_DIR/bin/$bin"
  if [[ -e "$f" ]]; then
    echo "✅ $bin found"
    # use -L to follow symlinks so we always test the final ELF file
    file -L "$f" | grep -q "ARM aarch64" \
      && echo "   ✅ Architecture: AArch64" \
      || echo "   ❌ Wrong architecture"
  else
    echo "❌ $bin not found"
  fi
}

# check the real compiler
check_binary clang-17     # ← was clang
check_binary mlir-tblgen
check_binary opt
check_binary llc

echo "✔️  Binary verification complete."
