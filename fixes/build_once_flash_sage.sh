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
XFORMERS_OUT=~/xformers-build

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


XFORMERS_WHEEL_DIR="$HOME/wheels/xformers-wheel"
echo "💥 Compilation xformers dans $XFORMERS_WHEEL_DIR"
mkdir -p "$XFORMERS_WHEEL_DIR"
[ -d xformers ] && rm -rf xformers
git clone --recursive https://github.com/facebookresearch/xformers.git -b v0.0.24
pushd xformers
python -m pip wheel . -w "$XFORMERS_WHEEL_DIR" --no-build-isolation --no-deps
popd
#rm -rf xformers

FLASH_WHEEL_DIR="$HOME/wheels/flashattn-wheel"
echo "💥 Compilation Flash-Attn dans $FLASH_WHEEL_DIR"
mkdir -p "$FLASH_WHEEL_DIR"
[ -d flash-attention ] && rm -rf flash-attention
git clone https://github.com/Dao-AILab/flash-attention.git -b v2.5.6
#git clone https://github.com/Dao-AILab/flash-attention.git -b v2.7.4
pushd flash-attention
python -m pip wheel . -w "$FLASH_WHEEL_DIR" --no-build-isolation --no-deps
popd
#rm -rf flash-attention

SAGE_WHEEL_DIR="$HOME/wheels/sageattn-wheel"
echo "🌿 Compilation Sage-Attn dans $SAGE_WHEEL_DIR"
mkdir -p "$SAGE_WHEEL_DIR"
# Clone du dépôt
[ -d SageAttention ] && rm -rf SageAttention
git clone https://github.com/thu-ml/SageAttention.git -b v2.0.1
pushd SageAttention

echo "🩹 Patch du setup.py pour corriger la variable 'num' manquante..."
sed -i '/arch=compute_{num},code=sm_{num}/c\    NVCC_FLAGS += ["-gencode", "arch=compute_87,code=sm_87"]' setup.py

python -m pip wheel . -w "$SAGE_WHEEL_DIR" --no-build-isolation --no-deps
popd
#rm -rf sage-attention

echo "🧩 Compilation de decord pour Jetson (sm_87)..."
DECORD_WHEEL_DIR="$HOME/wheels/decord-wheel"
rm -rf decord
mkdir -p "$DECORD_WHEEL_DIR"
git clone --recursive https://github.com/dmlc/decord.git -b v0.6.0
mkdir decord/build
pushd decord/build
cmake .. -DUSE_CUDA=0 -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
popd
pushd decord/python
python -m pip wheel . -w "$DECORD_WHEEL_DIR" --no-build-isolation --no-deps
popd


echo "🧩 Download onnxruntime pour Jetson (sm_87)..."
ONNXRUNTIME_WHEEL_DIR="$HOME/wheels/onnxruntime-wheel"
mkdir -p "$ONNXRUNTIME_WHEEL_DIR"
wget -P "$ONNXRUNTIME_WHEEL_DIR" \
  "https://pypi.jetson-ai-lab.dev/jp6/cu126/+f/869/e41abdc35e093/onnxruntime_gpu-1.22.0-cp310-cp310-linux_aarch64.whl"

conda deactivate
echo "✅ Compilation unique terminée avec succès."
