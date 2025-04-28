#!/usr/bin/env bash
set -e

# Sources : https://github.com/iperov/DeepFaceLab.git
# Scripts : https://gitee.com/zhanghongwei_cmiot/DeepFaceLab_Linux.git
# Guide : https://github.com/1lmao/Deep-Face-Lab

###############################################################################
# 0) “edit” mode ─ open the three main project files in Gedit, then exit
###############################################################################
if [[ "$1" == "edit" ]]; then
    gedit run_deepfacelab.sh docker-compose.yml docker/Dockerfile.jetson &
    exit 0
fi

###############################################################################
# 1) Create .env with your host UID / GID (only if not already present)
###############################################################################
ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "UID=$(id -u)" > "$ENV_FILE"
  echo "GID=$(id -g)" >> "$ENV_FILE"
  echo "✅ .env created with UID=$(id -u) and GID=$(id -g)"
else
  echo "ℹ️  .env already exists."
fi

###############################################################################
# 2) Build the image (cached layers make subsequent builds fast)
###############################################################################

clear

# Detect optional parameter --no-cache
BUILD_ARGS=""
if [[ "$1" == "--no-cache" ]]; then
    BUILD_ARGS="--no-cache"
fi

echo "🛠️  Building the DeepFaceLab image… this is slow only the first time."
docker compose --progress=plain build $BUILD_ARGS dfl

###############################################################################
# 3) Start an interactive container session
###############################################################################
echo "🚀  Starting the container — type exit to return to the host shell."
docker compose run --rm dfl

# docker compose run --rm --user root dfl
# python3
# import tensorflow as tf
# print(tf.config.list_physical_devices('GPU'))

# Fix lib dependency issues
# ls /usr/lib/aarch64-linux-gnu/libcblas*
# cd /usr/lib/aarch64-linux-gnu/ && \
# ln -sf libQt5Core.so.5.15.3 libQt5Core-9e162752.so.5.15.0 && \
# ldconfig

# cd /opt/DeepFaceLab_Linux/scripts/ && ./3_extract_image_from_data_dst.sh
# pip3 install --force-reinstall --no-cache-dir opencv-python-headless

# Procédure « clean » en 4 commandes
# 1) Désinstalle tous les wheels OpenCV éventuels
# pip3 uninstall -y opencv-python opencv-python-headless opencv-contrib-python || true

# 2) Supprime le répertoire résiduel déposé par le wheel (important)
# rm -rf /usr/local/lib/python3.10/dist-packages/cv2*  \
#        /usr/local/lib/python3.10/dist-packages/opencv*

# 3) Nettoie les librairies OpenCV 4.8/4.10 éventuellement installées par apt
# apt-get purge -y 'libopencv*-4.8*' 'libopencv*-4.9*' 'libopencv*-4.10*' || true
# apt-get autoremove -y

# 4) Installe la version Ubuntu (4.5.4) – sans dépendance cuDNN
# apt-get update
# apt-get install -y --no-install-recommends python3-opencv


echo
echo "ℹ️  Next time you can jump straight in with:"
echo "    docker compose run --rm dfl"
