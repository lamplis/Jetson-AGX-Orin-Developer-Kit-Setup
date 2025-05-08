#!/bin/bash
set -e

# Liste des virtualenvs à corriger (modifiez ici si nécessaire)
VENV_LIST=(
  "/home/lamplis/pinokio/api/hunyuanvideo.git/app/env"
  "/home/lamplis/pinokio/api/Frame-Pack.git/app/env"
)

echo "🧱 Vérification des dépendances système..."
sudo apt-get update
sudo apt-get install -y build-essential ninja-build cmake libopenblas-dev python3-dev

# Variables CUDA pour Orin
export TORCH_CUDA_ARCH_LIST="8.7"
export MAX_JOBS=12
export FORCE_CUDA=1
export CUDA_HOME=/usr/local/cuda-12.6 
export PATH=$CUDA_HOME/bin:$PATH

# Parcours des environnements
for VENV in "${VENV_LIST[@]}"; do
  echo "=============================="
  echo "🔧 Traitement de l'environnement : $VENV"
  echo "=============================="
  source "$VENV/bin/activate"
  
  echo "⬆️  Mise à jour pip / setuptools / wheel..."
  python -m pip install --upgrade pip setuptools wheel "packaging<25"

  echo "🧹 Nettoyage des anciennes installations..."
  python -m pip uninstall -y torch torchvision torchaudio xformers flash-attn flash_attn sage-attn || true

  echo "🔥 Installation de PyTorch via script local..."
  bash install_pytorch_jetson.sh

  echo "🚀 Installation de xformers (Jetson)..."
  python -m pip install "xformers==0.0.30+4cf69f0.d20250501" --no-cache

  echo "💥 Compilation Flash-Attn (v2.5.6)..."
  [ -d flash-attention ] && rm -rf flash-attention
  git clone https://github.com/Dao-AILab/flash-attention.git -b v2.5.6
  pushd flash-attention
  python setup.py install
  popd
  rm -rf flash-attention

  echo "🌿 Compilation Sage-Attn..."
  [ -d sage-attention ] && rm -rf sage-attention
  git clone https://github.com/OpenAccess-AI-Collective/sage-attention.git
  pushd sage-attention
  python setup.py install
  popd
  rm -rf sage-attention

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
    import sage_attn
    print("sage_attn OK")
except Exception as e:
    print("sage_attn KO:", e)
EOF

  deactivate
done

echo "✅ Tous les environnements corrigés avec succès."
