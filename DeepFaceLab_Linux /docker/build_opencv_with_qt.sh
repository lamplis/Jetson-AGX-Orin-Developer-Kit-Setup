#!/bin/bash
set -euxo pipefail

# Variables
OPENCV_VERSION="4.5.5"
NUM_CORES=2

# Dépendances
apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git pkg-config \
    libjpeg-dev libpng-dev libtiff-dev \
    libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev libxvidcore-dev libx264-dev \
    libgtk-3-dev libqt5gui5 libqt5widgets5 libqt5core5a qtbase5-dev \
    libatlas-base-dev gfortran python3-dev python3-numpy \
    libopenblas-dev libhdf5-dev

# Téléchargement des sources
cd /opt
rm -rf opencv opencv_contrib
git clone --depth 1 -b ${OPENCV_VERSION} https://github.com/opencv/opencv.git
git clone --depth 1 -b ${OPENCV_VERSION} https://github.com/opencv/opencv_contrib.git

# Création du dossier de build
mkdir -p /opt/opencv/build
cd /opt/opencv/build

# Configuration CMake
cmake -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D OPENCV_EXTRA_MODULES_PATH=/opt/opencv_contrib/modules \
      -D WITH_QT=ON \
      -D WITH_GTK=ON \
      -D WITH_OPENGL=ON \
      -D WITH_FFMPEG=ON \
      -D BUILD_opencv_python3=ON \
      -D PYTHON3_EXECUTABLE=$(which python3) \
      -D PYTHON3_INCLUDE_DIR=/usr/include/python3.10 \
      -D PYTHON3_LIBRARY=/usr/lib/aarch64-linux-gnu/libpython3.10.so \
      -D PYTHON3_PACKAGES_PATH=/usr/local/lib/python3.10/dist-packages \
      -D BUILD_TESTS=OFF \
      -D BUILD_EXAMPLES=OFF \
      -D BUILD_DOCS=OFF \
      ..

# Compilation (adaptée à Jetson)
make -j${NUM_CORES}
make install
ldconfig

# Nettoyage (optionnel)
rm -rf /opt/opencv /opt/opencv_contrib
