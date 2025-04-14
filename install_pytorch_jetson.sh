#!/bin/bash
set -e

echo "🚀 Installation de PyTorch pour Jetson AGX Orin (JetPack 6.4 + CUDA 12.8 + Python 3.10)"
echo "📦 Mise à jour et installation des dépendances système..."

sudo apt-get update
sudo apt-get install -y python3-pip libopenblas-dev

echo "🛠️ Téléchargement des whl compatibles..."
mkdir -p ~/Workspace/pytorch_wheels && cd ~/Workspace/pytorch_wheels

# PyTorch, torchvision, torchaudio - versions compatibles entre elles et CUDA 12.8
wget https://nvidia.box.com/shared/static/zvultzsmd4iuheykxy17s4l2n91ylpl8.whl -O torch-2.3.0-cp310-cp310-linux_aarch64.whl
wget https://nvidia.box.com/shared/static/u0ziu01c0kyji4zz3gxam79181nebylf.whl -O torchvision-0.18.0a0+6043bc2-cp310-cp310-linux_aarch64.whl
wget https://nvidia.box.com/shared/static/9agsjfee0my4sxckdpuk9x9gt8agvjje.whl -O torchaudio-2.3.0+952ea74-cp310-cp310-linux_aarch64.whl

echo "🐍 Création de l'environnement virtuel .venv..."
cd ~/Workspace
python3 -m venv .venv
source .venv/bin/activate

echo "⬆️ Mise à jour de pip et installation de numpy..."
python3 -m pip install --upgrade pip
python3 -m pip install numpy==1.26.1

echo "🔥 Installation de PyTorch, torchvision et torchaudio..."
cd ~/Workspace/pytorch_wheels
python3 -m pip install torch-2.3.0-cp310-cp310-linux_aarch64.whl
python3 -m pip install torchvision-0.18.0a0+6043bc2-cp310-cp310-linux_aarch64.whl
python3 -m pip install torchaudio-2.3.0+952ea74-cp310-cp310-linux_aarch64.whl

echo "✅ Vérification de l'installation..."
python3 -c "import torch; print('Torch version:', torch.__version__); print('CUDA dispo:', torch.cuda.is_available()); print('cuDNN version:', torch.backends.cudnn.version())"

echo "🎉 Installation terminée avec succès !"
