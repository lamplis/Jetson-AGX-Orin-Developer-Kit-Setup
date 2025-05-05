# Build and Run the container

```bash
cd ~/Workspace/DFL
chmod +x run_deepfacelab.sh
sudo mkdir /workspace
sudo chown -R $USER:$USER /workspace/
xhost +local:root  # authorize X11 local access

./run_deepfacelab.sh
```
You will be in the container.
Start with initializing your workspace

```bash
mkdir /workspace/model
cp -r /opt/DeepFaceLab/model_generic_xseg/* /workspace/model/
cp -r /opt/model/* /workspace/model/
```

Train Xseg
```bash
cd /opt/DeepFaceLab_Linux/scripts
./5_XSeg_train.sh
```
Debug in root mode
```bash
docker compose run --rm --user root dfl
```

# Check all Threads execution:
```bash
top -H -p $(pgrep -n -f DFL-GUI)
```

# Why is the Preview window frozen and not receiving any key inputs?
On **Ubuntu 22.04**, the OpenCV **4.5.4** version provided by the repository (`python3-opencv 4.5.4+dfsg-9ubuntu4`) uses the **HighGUI GTK3** backend.  
This backend:
- **Does not send keyboard events** to `cv::waitKey()`/`getWindowProperty()` (known issue: [https://github.com/opencv/opencv/issues/21460](https://github.com/opencv/opencv/issues/21460));
- **Sometimes blocks window refresh** when `imshow()` is called from a secondary thread (case of DeepFaceLab).

## **1) Remove the apt version**
```bash
sudo apt-get purge -y python3-opencv libopencv*
sudo apt-get autoremove -y
```

## **2) Install dependencies for Qt + video**
```bash
sudo apt-get install -y libqt5gui5 libqt5widgets5 libqt5core5a \
                        libavcodec58 libavformat58 libswscale5 libavutil56
```

## **3) Install OpenCV 4.5.5 (or later) using pip**
```bash
python3 -m pip install --upgrade pip wheel
```
Complete package (HighGUI Qt):
```bash
python3 -m pip install opencv-python==4.5.5.64
```




# Pour le Jetson : Modifier requirements-cuda.txt
```txt
# DeepFaceLab requirements optimized for Jetson (aarch64)

# Progress bar
tqdm

# Math libs
numpy==1.19.5
numexpr
h5py==2.10.0

# OpenCV for image operations (headless, lighter and ARM64 compatible)
opencv-python-headless==4.5.*

# Video processing
ffmpeg-python==0.1.17

# Image processing
scikit-image==0.19.3
scipy==1.10.0

# Terminal formatting
colorama

# TensorFlow: NVIDIA optimized build for JetPack
https://developer.download.nvidia.com/compute/redist/jp/v502/tensorflow/tensorflow-1.15.5+nv22.12-cp38-cp38-linux_aarch64.whl

# Optional: model export
tf2onnx==1.9.3
```

/workspace# pip3  install -r ./DeepFaceLab/requirements-cuda.txt
pip3 install --no-cache-dir colorama numexpr

ERROR: No matching distribution found for opencv-python==4.1.0.25

👉 **Explication rapide** :

- Le `requirements-cuda.txt` de **DeepFaceLab** te demande **`opencv-python==4.1.0.25`**.
- **Or cette version précise n'existe pas** pour `linux/aarch64` (ton architecture Jetson).
- **Sur Jetson**, tu dois utiliser **`opencv-python-headless 4.5.*`** (comme déjà installé dans ton Dockerfile).

---

## 🛠️ Ce qu’on fait maintenant :

**Ne PAS essayer d'installer `opencv-python==4.1.0.25`.**  
C’est inutile et surtout **impossible** sur Jetson.

**Solution** :  
Ignore l'erreur et installe manuellement ce qu'il reste :

```bash
pip3 install --no-cache-dir colorama numexpr
```

## 📋 Résumé ultra clair :

| Paquet             | État                     |
|--------------------|---------------------------|
| tqdm               | ✅ Déjà installé |
| numpy==1.19.3       | ⚠️ mais on a 1.19.5 (ok, très proche) |
| h5py==2.10.0        | ✅ Déjà installé |
| opencv-python==4.1.0.25 | ❌ Impossible → on utilise opencv-python-headless==4.5.* |
| colorama           | ❌ À installer |
| numexpr            | ❌ À installer |

---

#Debug error 

dfluser@ea3bae47cad9:/workspace/scripts$ ./3_extract_image_from_data_dst.sh
Traceback (most recent call last):
  File "/workspace/DeepFaceLab/main.py", line 6, in <module>
    from core.leras import nn
  File "/workspace/DeepFaceLab/core/leras/__init__.py", line 1, in <module>
    from .nn import nn
  File "/workspace/DeepFaceLab/core/leras/nn.py", line 26, in <module>
    from core.interact import interact as io
  File "/workspace/DeepFaceLab/core/interact/__init__.py", line 1, in <module>
    from .interact import interact
  File "/workspace/DeepFaceLab/core/interact/interact.py", line 9, in <module>
    import cv2
  File "/usr/local/lib/python3.10/dist-packages/cv2/__init__.py", line 8, in <module>
    from .cv2 import *
ImportError: libavcodec-e61fde82.so.58.134.100: cannot open shared object file: No such file or directory
dflus
boot as root:
docker compose run --rm --user root dfl

apt-get update && apt-get install --reinstall -y libopencv-dev python3-opencv

# Erreur :
./5_XSeg_data_dst_mask_apply.sh => Exception: /workspace/model/XSeg_256.npy does not exists.

## Mettre le model XSeg
here xseg 14M download it https://drive.google.com/file/d/1mvtdSlSP-SP6HFTEKy4RE63X6GnyY74w/view?usp=sharing
cd ~/Workspace/DF/docker
sudo mkdir -p ../workspace/DeepFaceLab/model_generic_xseg
sudo unzip Xseg14m.zip -d ~/Workspace/DF/workspace/DeepFaceLab/model_generic_xseg/


## télécharger pretrained DF.wf.288res.384.92.72.22 : https://github.com/iperov/DeepFaceLab/releases/tag/DF.wf.288res.384.92.72.22
cd ~/Workspace/DF/docker
sudo mkdir -p ../workspace/model
sudo unzip DF.wf.288res.384.92.72.22.zip -d ../workspace/



#unzip to a "model" folder
lamplis@ubuntu:~/Downloads$ ls model/
new_SAEHD_data.dat         new_SAEHD_encoder.npy  SAEHD_default_options.dat
new_SAEHD_decoder_dst.npy  new_SAEHD_inter.npy
new_SAEHD_decoder_src.npy  new_SAEHD_summary.txt

mkdir -p /workspace/DeepFaceLab/model_generic_xseg
mv DeepFaceLab_XSeg_generic_wf/* /workspace/DeepFaceLab/model_generic_xseg/




