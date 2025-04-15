#!/bin/bash
set -e

echo "🚀 Building CTranslate2 optimized for Jetson AGX Orin (JetPack 6.4 + CUDA 12.x)"

echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y \
    cmake g++ git ninja-build \
    libprotobuf-dev protobuf-compiler \
    libutf8proc-dev libsentencepiece-dev \
    zlib1g-dev python3-dev libgomp1

echo "✅ Dependencies installed"

# Clone the repository with all bindings
cd ~/Workspace
rm -rf CTranslate2
git clone --recursive https://github.com/OpenNMT/CTranslate2.git
cd CTranslate2

# Paths
REPO_DIR=$(pwd)
BUILD_DIR="$REPO_DIR/build"

echo "🧹 Cleaning build directory..."
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

echo "🛠 Configuring CMake with CUDA (arch 8.7)..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="87" \
    -DWITH_MKL=OFF \
    -DWITH_CUDNN=ON \
    -DOPENMP_RUNTIME=NONE \
    -DCMAKE_INSTALL_PREFIX=/usr/local

echo "⚙️ Compiling..."
make -j$(nproc)

sudo make install
sudo ldconfig

echo "📦 Copying shared library to /usr/local/lib"
sudo cp libctranslate2.so* /usr/local/lib/

echo "🔗 Creating symbolic links..."
cd /usr/local/lib
sudo ln -sf libctranslate2.so.4.6.0 libctranslate2.so.4
sudo ln -sf libctranslate2.so.4 libctranslate2.so
sudo ldconfig

echo "🐍 Installing Python bindings"

# Compile the Python wrapper
cd $REPO_DIR/python
pip uninstall -y setuptools
pip install 'setuptools==68.2.2'
pip install --upgrade pip wheel
pip install --upgrade packaging

pip install -r install_requirements.txt
python setup.py bdist_wheel
pip install --force-reinstall dist/*.whl

echo "✅ CTranslate2 successfully built and installed!"
