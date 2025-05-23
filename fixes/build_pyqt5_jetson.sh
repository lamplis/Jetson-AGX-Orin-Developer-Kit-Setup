#!/bin/bash
set -e

# === Configuration ===
PYQT_VERSION="5.15.10"
SIP_VERSION="6.8.0"
CACHE_DIR="$HOME/.cache/dfl_wheels"
mkdir -p "$CACHE_DIR"

# === Install system dependencies ===
echo "📦 Installing system packages..."
#sudo apt-get update
sudo apt-get install -y \
  qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
  libqt5gui5 libqt5widgets5 libqt5core5a libqt5dbus5 \
  libqt5network5 libgl1-mesa-dev \
  build-essential wget

# === Install Python build dependencies ===
echo "🐍 Ensuring Python build dependencies..."
pip install -U pip wheel setuptools packaging tomli pyqt-builder

# === Build and install sip ===
cd /tmp
echo "⬇️  Downloading sip $SIP_VERSION..."
wget -q https://files.pythonhosted.org/packages/source/s/sip/sip-${SIP_VERSION}.tar.gz
tar -xf sip-${SIP_VERSION}.tar.gz
cd sip-${SIP_VERSION}
echo "⚙️  Installing sip..."
python3 -m pip install . --force-reinstall

# === Build PyQt5 ===
cd /tmp
echo "⬇️  Downloading PyQt5 $PYQT_VERSION..."
wget -q https://files.pythonhosted.org/packages/source/P/PyQt5/PyQt5-${PYQT_VERSION}.tar.gz
tar -xf PyQt5-${PYQT_VERSION}.tar.gz
cd PyQt5-${PYQT_VERSION}

echo "📝 Creating pyproject configuration to disable QtWebEngine..."
cat > pyproject.toml <<EOF
[project]
name = "PyQt5"
version = "5.15.10"

[build-system]
requires = ["sip >=6.8"]
build-backend = "sipbuild.api"
EOF

cat > pyproject.cfg <<EOF
[sip.project]
disable = QtWebEngine
EOF

echo "🏗️  Running sip-install (without make)..."
sip-install --no-make

echo "🧱 Compiling PyQt5..."
make -j$(nproc)

echo "📦 Building wheel..."
pip wheel . -w "$CACHE_DIR"

echo "✅ PyQt5 $PYQT_VERSION built and stored in: $CACHE_DIR"
