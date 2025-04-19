#!/bin/bash
set -e

# Flags
USE_VENV=false
CLEAN_CACHE=false

# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --venv)
      USE_VENV=true
      ;;
    --clean-cache)
      CLEAN_CACHE=true
      ;;
  esac
done

echo "🚀 Installing PyTorch for Jetson AGX Orin (JetPack 6.4 + CUDA 12.6 + Python 3.10)"
echo "📦 Updating system packages..."

pip uninstall -y torch torchvision torchaudio

# Install base dependencies
sudo apt-get update
sudo apt-get install -y python3-pip libopenblas-dev

# Cache directory for .whl files
WHEEL_CACHE=~/.cache/pytorch_wheels
mkdir -p "$WHEEL_CACHE"
cd "$WHEEL_CACHE"

# Wheel filenames

TORCH_WHL=torch-2.6.0+cu126-cp310-cp310-linux_aarch64.whl
TORCHAUDIO_WHL=torchaudio-2.6.0-cp310-cp310-linux_aarch64.whl
TORCHVISION_WHL=torchvision-0.21.0-cp310-cp310-linux_aarch64.whl


# Clean cache if requested
if $CLEAN_CACHE; then
  echo "🧹 Cleaning wheel cache..."
  rm -f "$WHEEL_CACHE"/*.whl
fi

# Download only if not cached
echo "⬇️ Downloading missing wheels (if any)..."

#https://download.pytorch.org/whl/cu124
[ ! -f "$TORCH_WHL" ] && wget https://download.pytorch.org/whl/cu126/torch-2.6.0%2Bcu126-cp310-cp310-linux_aarch64.whl -O "$TORCH_WHL"
[ ! -f "$TORCHAUDIO_WHL" ] && wget https://download.pytorch.org/whl/cu126/torchaudio-2.6.0-cp310-cp310-linux_aarch64.whl -O "$TORCHAUDIO_WHL"
[ ! -f "$TORCHVISION_WHL" ] && wget https://download.pytorch.org/whl/cu126/torchvision-0.21.0-cp310-cp310-linux_aarch64.whl -O "$TORCHVISION_WHL"




# Optional: virtual environment
if $USE_VENV; then
  echo "🐍 Creating virtual environment..."
  cd ~/Workspace
  python3 -m venv .venv
  source .venv/bin/activate
else
  echo "⚠️ Using system Python (no virtual environment)."
fi

# Install Python packages
echo "⬆️ Installing pip and numpy..."
python3 -m pip install --upgrade pip
python3 -m pip install --force-reinstall "numpy<2.0" 

# Install PyTorch stack
echo "🔥 Installing PyTorch, TorchVision, and Torchaudio..."
python3 -m pip install "$WHEEL_CACHE/$TORCH_WHL"
python3 -m pip install "$WHEEL_CACHE/$TORCHVISION_WHL"
python3 -m pip install "$WHEEL_CACHE/$TORCHAUDIO_WHL"

# Verify
echo "✅ Verifying installation..."
python3 -c "import torch, torchvision, torchaudio;
print('Torch:', torch.__version__);
print('TorchVision:', torchvision.__version__);
print('Torchaudio:', torchaudio.__version__);
print('PyTorch CUDA version:', torch.version.cuda)
print('CUDA available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('CUDA device name:', torch.cuda.get_device_name(0))
    print('CUDA device capability:', torch.cuda.get_device_capability(0))"

echo "🎉 Done!"
