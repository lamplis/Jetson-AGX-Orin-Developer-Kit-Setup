#!/bin/bash
set -e

# Activation Conda (Pinokio)
PINOKIO_CONDA="$HOME/pinokio/bin/miniconda"
CONDA_SH="$PINOKIO_CONDA/etc/profile.d/conda.sh"

if [ ! -f "$CONDA_SH" ]; then
  echo "❌ Conda via Pinokio introuvable à $CONDA_SH"
  exit 1
fi

# Charger Conda dans l'environnement shell
source "$CONDA_SH"

# Paramètres
BUILD_ENV_NAME="flashattn-build"
FLASH_OUT=~/flashattn-build
SAGE_OUT=~/sageattn-build

echo "🛠️ Création de l'environnement Conda de build : $BUILD_ENV_NAME"
conda remove -y -n "$BUILD_ENV_NAME" --all || true
conda create -y -n "$BUILD_ENV_NAME" python=3.10
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "$BUILD_ENV_NAME"

# Dépendances système (si manquantes)
sudo apt-get install -y build-essential ninja-build cmake libopenblas-dev

echo "⬆️  Mise à jour pip / setuptools / wheel..."
python -m pip install --upgrade pip setuptools wheel "packaging<25"

echo "🧹 Nettoyage des anciennes installations..."
python -m pip uninstall -y torch torchvision torchaudio xformers flash-attn flash_attn sage-attn || true

# PyTorch avec CUDA
bash install_pytorch_jetson.sh

# Variables CUDA pour Orin
export TORCH_CUDA_ARCH_LIST="8.7"
export MAX_JOBS=4
export FORCE_CUDA=1
export CUDA_HOME=/usr/local/cuda-12.6
export PATH=$CUDA_HOME/bin:$PATH

echo "💥 Compilation Flash-Attn dans $FLASH_OUT"
FLASH_WHEEL_DIR="$HOME/flashattn-wheel"
mkdir -p "$FLASH_WHEEL_DIR"
[ -d flash-attention ] && rm -rf flash-attention
git clone https://github.com/Dao-AILab/flash-attention.git -b v2.5.6
pushd flash-attention
python -m pip wheel . -w "$FLASH_WHEEL_DIR" --no-build-isolation --no-deps
popd
rm -rf flash-attention

echo "🌿 Compilation Sage-Attn dans $SAGE_OUT"
SAGE_WHEEL_DIR="$HOME/sageattn-wheel"
mkdir -p "$SAGE_WHEEL_DIR"
# Clone du dépôt
[ -d sage-attention ] && rm -rf SageAttention
git clone https://github.com/thu-ml/SageAttention.git
pushd SageAttention

echo "🩹 Patch du setup.py pour corriger la variable 'num' manquante..."
sed -i '/arch=compute_{num},code=sm_{num}/c\    NVCC_FLAGS += ["-gencode", "arch=compute_87,code=sm_87"]' setup.py

python -m pip wheel . -w "$SAGE_WHEEL_DIR" --no-build-isolation --no-deps
popd

rm -rf sage-attention

conda deactivate
echo "✅ Compilation unique terminée avec succès."
