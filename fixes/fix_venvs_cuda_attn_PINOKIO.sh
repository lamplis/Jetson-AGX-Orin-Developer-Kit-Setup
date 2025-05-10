#!/bin/bash
set -e

# Liste des virtualenvs à corriger (modifiez ici si nécessaire)
VENV_LIST=(
#  "/home/lamplis/pinokio/api/hunyuanvideo.git/app/env"
#  "/home/lamplis/pinokio/api/Frame-Pack.git/app/env"
  "/home/lamplis/pinokio/api/wan.git/app/env"
)

echo "🧱 Vérification des dépendances système..."
sudo apt-get update
sudo apt-get install -y build-essential ninja-build cmake libopenblas-dev python3-dev

# Variables CUDA pour Orin
export TORCH_CUDA_ARCH_LIST="8.7"
export MAX_JOBS=4
export FORCE_CUDA=1
export CUDA_HOME=/usr/local/cuda-12.6 
export PATH=$CUDA_HOME/bin:$PATH

# Parcours des environnements
for VENV in "${VENV_LIST[@]}"; do
  echo "=============================="
  echo "🔧 Traitement de l'environnement : $VENV"
  echo "=============================="
  deactivate || true
  source "$VENV/bin/activate"
  
  echo "⬆️  Mise à jour pip / setuptools / wheel..."
  python -m pip install --upgrade pip setuptools wheel "packaging<25"

  echo "🧹 Nettoyage des anciennes installations..."
  python -m pip uninstall -y torch torchvision torchaudio xformers flash-attn flash_attn sage-attn || true

  echo "🔥 Installation de PyTorch via script local..."
  bash install_pytorch_jetson.sh

  echo "🚀 Installation de xformers (Jetson)..."
  #python -m pip install "xformers==0.0.24" --no-cache
  python -m pip install --no-index --no-deps --force-reinstall \
  "$HOME/wheels/xformers-wheel"/xformers-*.whl

  echo "📦 Installation Flash-Attn compilé..."
  python -m pip install --no-index --no-deps --force-reinstall \
  "$HOME/wheels/flashattn-wheel"/flash_attn-*.whl

  echo "📦 Installation Sage-Attn compilé..."
  python -m pip install --no-index --no-deps --force-reinstall \
  "$HOME/wheels/sageattn-wheel"/sageattention-*.whl
  
  echo "📦 Installation decord compilé..."
  python -m pip install --no-index --no-deps --force-reinstall \
  "$HOME/wheels/decord-wheel"/decord-*.whl

  echo "📦 Installation onnxruntime..."
  python -m pip install --no-index --no-deps --force-reinstall \
  "$HOME/wheels/onnxruntime-wheel"/onnxruntime_gpu-*.whl

  echo "✅ Vérification de l'installation dans $VENV"
  python - <<'EOF'
import torch
print("Torch:", torch.__version__, "| CUDA:", torch.version.cuda)
print("CUDA OK:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))

import xformers, xformers.ops
print("xformers:", xformers.__version__)
print("FlashAttn in xformers:", xformers.ops.memory_efficient_attention is not None)

try:
    import flash_attn
    print("flash_attn OK:", flash_attn.__version__)
except Exception as e:
    print("flash_attn KO:", e)

try:
    import sageattention
    print("sageattention OK")
except Exception as e:
    print("sageattention KO:", e)
EOF

  echo "✅ Vérification de Decord dans $VENV"
python - <<'EOF'
import os, urllib.request, numpy as np, decord, contextlib
from decord import VideoReader, cpu

print("✅ Decord version:", decord.__version__)

url = "https://file-examples.com/storage/feaf304f8a681f45d9c35d4/2017/04/file_example_MP4_640_3MG.mp4"
video_path = "sample_cpu_test.mp4"
downloaded = False

# 1) Fetch clip if missing
if not os.path.exists(video_path):
    print("⬇️  Downloading test clip …")
    urllib.request.urlretrieve(url, video_path)
    downloaded = True
    print("✅  Download complete.")

# 2) Open with CPU context
vr = VideoReader(video_path, ctx=cpu(0))
print(f"🎞️  Loaded | frames: {len(vr)} | shape: {vr[0].shape}")

# 3) Assertions
frame0 = vr[0].asnumpy()
assert frame0.ndim == 3 and isinstance(frame0, np.ndarray)
print("✅  Frame‑0 dtype:", frame0.dtype, "| min/max:", frame0.min(), frame0.max())

print("\n🎉  Decord CPU test finished successfully.")

# 4) Clean‑up
with contextlib.suppress(Exception):
    os.remove(video_path)
    print("🧹  Sample file removed.")
EOF



  deactivate
done

echo "✅ Tous les environnements corrigés avec succès."
