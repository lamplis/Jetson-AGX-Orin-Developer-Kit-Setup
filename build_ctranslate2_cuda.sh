#!/bin/bash

set -e

echo "🚀 Build de CTranslate2 optimisé pour Jetson AGX Orin (JetPack 6.4 + CUDA 12.x)"

# 📦 Installation des dépendances système
echo "📦 Installation des dépendances système..."
sudo apt-get update
sudo apt-get install -y \
  g++ cmake git \
  libprotobuf-dev protobuf-compiler \
  libutf8proc-dev libsentencepiece-dev \
  zlib1g-dev python3-dev ninja-build

# 📁 Répertoire de build
cd ~/Workspace

# 📦 Clone si nécessaire
if [ ! -d "CTranslate2" ]; then
  echo "📥 Clonage de CTranslate2..."
  git clone --recursive https://github.com/OpenNMT/CTranslate2.git
else
  echo "✅ Déjà cloné"
fi

cd CTranslate2

# 🩹 Patch : éviter les erreurs liées à MKL et iomp5
echo "🩹 Patch des erreurs MKL/iomp5 dans le CMakeLists.txt..."
sed -i '/find_package(MKL/d' CMakeLists.txt
sed -i '/find_package(IntelOMP/d' CMakeLists.txt
sed -i '/MKL_INCLUDE_DIR/d' CMakeLists.txt
sed -i '/INTEL_OMP_INCLUDE_DIR/d' CMakeLists.txt
sed -i '/INTEL_OMP_LIBRARY/d' CMakeLists.txt

# 🛠 Build
echo "🛠 Configuration CMake avec CUDA (arch 8.7)..."
mkdir -p build && cd build
rm -rf *

cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_CUDA=ON \
  -DWITH_MKL=OFF \
  -DCUDA_ARCH_LIST="8.7" \
  -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
  -DCMAKE_INSTALL_PREFIX=~/Workspace/ctranslate2-install

make -j$(nproc)

echo "📦 Installation dans ~/Workspace/ctranslate2-install"
make install
