#!/usr/bin/env bash
set -e   # abort as soon as any command fails

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
ENV_FILE=.env
if ! grep -q "^UID=" "$ENV_FILE" 2>/dev/null; then
    echo "UID=$(id -u)"  > "$ENV_FILE"
    echo "GID=$(id -g)" >> "$ENV_FILE"
    echo "📝  .env created with UID=$(id -u) and GID=$(id -g)"
fi

###############################################################################
# 2) Build the image (cached layers make subsequent builds fast)
###############################################################################
clear
echo "🛠️  Building the DeepFaceLab image… this is slow only the first time."
docker compose --progress=plain build dfl

###############################################################################
# 3) Start an interactive container session
###############################################################################
echo "🚀  Starting the container — type exit to return to the host shell."
docker compose run --rm dfl

echo
echo "ℹ️  Next time you can jump straight in with:"
echo "    docker compose run --rm dfl"
