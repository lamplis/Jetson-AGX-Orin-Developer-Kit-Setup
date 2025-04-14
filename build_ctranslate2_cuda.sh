#!/bin/bash
set -e

echo "🚀 Build de CTranslate2 optimisé pour Jetson AGX Orin (JetPack 6.4 + CUDA 12.x)"

echo "📦 Installation des dépendances système..."
sudo apt update
sudo apt install -y \
    cmake g++ git ninja-build \
    libprotobuf-dev protobuf-compiler \
    libutf8proc-dev libsentencepiece-dev \
    zlib1g-dev python3-dev libgomp1

echo "✅ Dépendances installées"

# cloner le dépôt avec tous les bindings
cd ~/Workspace
rm -rf CTranslate2
git clone --recursive https://github.com/OpenNMT/CTranslate2.git
cd CTranslate2

# Chemins
REPO_DIR=$(pwd)
BUILD_DIR="$REPO_DIR/build"

echo "🧹 Nettoyage..."
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

echo "🛠 Configuration CMake avec CUDA (arch 8.7)..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="87" \
    -DWITH_MKL=OFF \
    -DWITH_CUDNN=ON \
    -DOPENMP_RUNTIME=NONE \
    -DCMAKE_INSTALL_PREFIX=/usr/local

echo "⚙️ Compilation..."
make -j$(nproc)

sudo make install
sudo ldconfig

echo "📦 Installation de la bibliothèque partagée dans /usr/local/lib"
sudo cp libctranslate2.so* /usr/local/lib/

echo "🔗 Configuration des liens symboliques..."
cd /usr/local/lib
sudo ln -sf libctranslate2.so.4.6.0 libctranslate2.so.4
sudo ln -sf libctranslate2.so.4 libctranslate2.so
sudo ldconfig

echo "✅ CTranslate2 compilé et installé avec succès !"

# Compile the Python wrapper
cd $REPO_DIR/python
pip install -r install_requirements.txt
python setup.py bdist_wheel
pip install dist/*.whl
