#!/bin/bash
set -e

log_step() {
  echo -e "\n🟦 $1\n"
}

install_deps() {
  log_step "Installation des dépendances système..."
  sudo apt update
  sudo apt install -y \
    cmake g++ git ninja-build \
    libprotobuf-dev protobuf-compiler \
    libutf8proc-dev libsentencepiece-dev \
    zlib1g-dev python3-dev libgomp1
}

clone_repo() {
  log_step "Clonage ou mise à jour du dépôt CTranslate2..."

  cd ~/Workspace
  if [ -d "CTranslate2/.git" ]; then
    cd CTranslate2
    git fetch origin
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    BASE=$(git merge-base @ @{u})

    if [ "$LOCAL" = "$REMOTE" ]; then
      echo "✅ Le dépôt est déjà à jour."
    elif [ "$LOCAL" = "$BASE" ]; then
      echo "⬆️ Mise à jour du dépôt..."
      git pull --recurse-submodules
    else
      echo "⚠️ Le dépôt a des modifications locales ou un historique divergent."
      echo "🧹 Suppression et re-clonage pour repartir proprement..."
      cd ..
      rm -rf CTranslate2
      git clone --recursive https://github.com/OpenNMT/CTranslate2.git
    fi
  else
    echo "📥 Clonage du dépôt CTranslate2..."
    git clone --recursive https://github.com/OpenNMT/CTranslate2.git
  fi
  
  echo "⚠️ Ensure submodules are properly initialized and updated"
  cd ~/Workspace/CTranslate2
  git submodule deinit -f .
  git submodule update --init --recursive
}

build_cpp() {
  log_step "Purge des données"
  
# sudo apt remove ctranslate2
# sudo apt purge ctranslate2

sudo apt autoremove
sudo rm -f /usr/local/lib/libctranslate2.so*
sudo rm -rf /usr/local/include/ctranslate2
sudo ldconfig
sudo rm -rf /usr/local/lib/cmake/ctranslate2
sudo rm -f /usr/local/bin/ct2-translator
sudo ldconfig
  
  log_step "Configuration et compilation C++..."
  cd ~/Workspace/CTranslate2
  mkdir -p build && cd build
  cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="87" \
    -DWITH_MKL=OFF \
    -DWITH_CUDNN=ON \
    -DOPENMP_RUNTIME=NONE \
    -DCMAKE_INSTALL_PREFIX=/usr/local

  make -j$(nproc)
  sudo make install
  sudo ldconfig
  
  #echo "📦 Copying shared library to /usr/local/lib"
  #sudo cp libctranslate2.so* /usr/local/lib/
  
  #echo "🔗 Creating symbolic links..."
  #cd /usr/local/lib
  #sudo ln -sf libctranslate2.so.4.6.0 libctranslate2.so.4
  #sudo ln -sf libctranslate2.so.4 libctranslate2.so
  #sudo ldconfig
}

build_python() {
  log_step "Build et installation Python..."
  cd ~/Workspace/CTranslate2/python
  #echo -e "[build-system]\nrequires = [\"setuptools>=40.8.0\", \"wheel\", \"pybind11\"]\nbuild-backend = \"setuptools.build_meta\"" > pyproject.toml
    
  echo "🧹 Nettoyage du build Python"
  sudo rm -rf build dist 
  pip3 uninstall -y ctranslate2 setuptools pybind11
  sudo rm -rf ~/.local/lib/python3.10/site-packages/ctranslate2*
  
  pip3 install 'setuptools==68.2.2' 'matplotlib==3.10.1' 'pybind11<2.12.0' --force-reinstall 
  pip3 install --upgrade pip wheel
 
  #pip3 install --no-build-isolation --force-reinstall --no-cache-dir -r install_requirements.txt
  pip3 install --no-build-isolation --no-cache-dir ./
  
  #log_step "Ajout du header manquant module.h pour le build Python"
  #ln -sf ../src/module.h cpp/module.h

  python3 setup.py bdist_wheel
  #python3 -m build
  pip3 install --force-reinstall dist/*.whl
}

main() {
  log_step "🚀 Build de CTranslate2 optimisé pour Jetson AGX Orin (JetPack 6.2 + CUDA 12.x)"
  install_deps
  clone_repo
  build_cpp
  build_python
  log_step "✅ Build terminé avec succès !"
  
  log_step "✅ Expect ['int8', 'float16', 'float32']"
  python3 -c "import ctranslate2; print(ctranslate2.get_supported_compute_types('cuda'))"

}

main
