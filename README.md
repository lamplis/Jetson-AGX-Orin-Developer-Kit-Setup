# Jetson-AGX-Orin-Developer-Kit-Setup
Setup guide for Jetson AGX Orin Developer Kit using WSL2 Windows 11

# 1 Install Docker Desktop

# 2 Install ubuntu 22.04 WSL 2
[Setup for WSL2](https://docs.nvidia.com/sdk-manager/wsl-systems/index.html)

- Install Linux distributions that comply with the SDK you are about to install
-- open powershell in admin mode
-- Ensure you have the latest WSL kernel with the following command:
```shell
wsl.exe --update
``` 
-- See a list of available distros with the following command:
```shell
wsl --list --online
```
-- Install the required distribution by running the below command
```shell
wsl --install -d Ubuntu-22.04
```

-- If you need to clean
```shell
wsl --list --verbose
wsl --unregister Ubuntu-24.04
```

-- To flash a NVIDIA physical device which is connected over USB to your host Windows machine, you will need to install USBIPD. USBIPD version 4.3.0 or higher is required
```shell
winget install --interactive --exact dorssel.usbipd-win
```

# 3 Setup the Linux Distribution Environment

- Upgrade Ubuntu
```shell
sudo apt update && sudo apt full-upgrade -y
```

- Run the following command to uninstall all conflicting packages:
```shell
 for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
```

- Set up Docker's apt repository.
```shell
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get purge docker-ce docker-ce-cli containerd.io
sudo apt-get autoremove

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

```

- To install the latest version, run:
```shell
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

- Verify that the installation is successful by running the hello-world image:
```shell
sudo docker run hello-world
```

```shell
sudo apt-get update
sudo apt-get install docker-compose-plugin
```
- It is recommended that you install the wslu package:
```shell
sudo apt update && sudo apt install wslu -y
```
- Install additional recommended packages by running the below commands:
```shell
sudo apt update && sudo apt install iputils-ping iproute2 netcat iptables dnsutils network-manager usbutils net-tools python3-yaml dosfstools libgetopt-complete-perl openssh-client binutils xxd cpio udev dmidecode -y
```
- To flash a NVIDIA device connected over USB, install the following packages by running the below commands:
```shell
sudo apt install linux-tools-virtual hwdata
```

- Known Issues : to avoid 'dpkg': Exec format error :
```shell
sudo apt update && sudo apt install qemu-user-static binfmt-support
sudo update-binfmts --enable
```

- Install SDK Manager, which is available from https://developer.nvidia.com/nvidia-sdk-manager.
It is recommended that you download the client via a Windows host machine browser and copy it to a WSL folder (usually available at \\wsl$). From a Linux distribution, using a network repo is the recommended method.

# 4 Flash a Jetson Device

## Run your WSL Linux distribution.

1. Connect the Jetson device to a USB port on your Windows machine.
2. Boot the Jetson device into Recovery mode : press and maintain the mid button, the press and maintain 2s the reset button on the rigth and release both buttons at the same time
3. Attach the USB BUS ID of the Jetson device to the WSL distribution.

### Identify the Jetson Device

From a Windows PowerShell administrator terminal, run the following command:

```powershell
usbipd.exe list
```

Identify the BUS ID of the selected Jetson device (starting with `0955`).

### Attach the Jetson Device to WSL

Attach the BUS ID to the WSL Linux distribution by running the following commands:

```powershell
wsl --list --verbose
wsl --set-default Ubuntu-22.04

usbipd.exe bind --busid <BUSID> --force
usbipd.exe attach --wsl --busid=<BUSID> --auto-attach
```

### Validate the Connection

Run the following command in WSL to ensure the Jetson device appears:

```bash
~/SDK$ lsusb
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 002: ID 0955:7020 NVIDIA Corp. L4T (Linux for Tegra) running on Tegra
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
```

## Install SDK Manager

### Without Docker

# DOWNLOAD and INSTALL SDKmanager:
```shell
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install sdkmanager
```

# LAUNCH:
- From a terminal window, launch SDK Manager with the command: 
```shell
sdkmanager --cli --action install --login-type devzone --product Jetson --target-os Linux --version 6.2 --target JETSON_AGX_ORIN_TARGETS --flash --license accept --stay-logged-in true --collect-usage-data enable --exit-on-finish
```

fOR mANUAL fLASHING
```shell
export L4T_RELEASE_PACKAGE="Jetson_Linux_R36.4.3_aarch64.tbz2" SAMPLE_FS_PACKAGE="Tegra_Linux_Sample-Root-Filesystem_R36.4.3_aarch64.tbz2" BOARD="jetson-agx-orin-devkit"
```

List of boards = https://docs.nvidia.com/jetson/archives/r36.4/DeveloperGuide/IN/QuickStart.html#jetson-modules-and-configurations

```shell
tar xf ${L4T_RELEASE_PACKAGE}
sudo tar xpf ${SAMPLE_FS_PACKAGE} -C Linux_for_Tegra/rootfs/
cd Linux_for_Tegra/
sudo ./tools/l4t_flash_prerequisites.sh
sudo ./apply_binaries.sh
```

```shell
sudo ./tools/kernel_flash/l4t_initrd_flash.sh --external-device nvme0n1p1 \
  -c tools/kernel_flash/flash_l4t_t234_nvme.xml \
  --showlogs --network usb0 jetson-agx-orin-devkit external
```
```shell
sdkmanager --cli --action install --login-type devzone --product Jetson --target-os Linux --version 6.2 --target JETSON_AGX_ORIN_TARGETS --flash --license accept --stay-logged-in true --collect-usage-data enable --exit-on-finish
```

# ERROR: might be timeout in USB write.
On some systems, USB autosuspend can interfere with the flashing process. Disable it by running:
bash
echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend


## Run the SDK Manager to Flash

Using Docker :

Since WSL2 mounts the root filesystem (/) by default, you need to explicitly remount it with shared propagation.
Remount / as shared:
```shell
sudo mount --make-shared /
```

### Build image
- Download SDK manager on the Linux VM.
NVIDIA Developer users: the most recent version of NVIDIA SDK Manager can be downloaded from: https://developer.nvidia.com/nvidia-sdk-manager.
- Download the file to your host machine : \\wsl.localhost\Ubuntu-22.04\home\USERNAME\SDK\sdkmanager-2.2.0.12028-Ubuntu_22.04_docker.tar.gz

```shell
mkdir ~/SDK
cd ~/SDK
sudo docker load -i ./sdkmanager-2.2.0.12028-Ubuntu_22.04_docker.tar.gz
sudo docker tag sdkmanager:2.2.0.12028-Ubuntu_22.04 sdkmanager:latest
```
Then run SDKmanager

```shell
sudo docker run -it --privileged -v /dev/bus/usb:/dev/bus/usb/ -v /dev:/dev -v /media/$USER:/media/nvidia:slave --name JetPack_AGX_Orin_Devkit --network host sdkmanager --cli --action install --login-type devzone --product Jetson --target-os Linux --version 6.2 --target JETSON_AGX_ORIN_TARGETS --flash --license accept --stay-logged-in true --collect-usage-data enable --exit-on-finish
```

if it fails, just retry. You'll have an error 

```shell
docker: Error response from daemon: Conflict. The container name "/JetPack_AGX_Orin_Devkit" is already in use by container "a6437d6652e22930ea880bc47af5cbcf5c76efc1066bb27b624423b278376fe5". You have to remove (or rename) that container to be able to reuse that name.
```

stop it

```shell
docker stop JetPack_AGX_Orin_Devkit
sudo docker rm CONTAINER_ID
```
then retry

1. Run SDK Manager in CLI mode (or GUI if enabled).
2. Select the device that is attached to your machine.
3. In the SDK Manager flash configuration dialog (Step 3), choose **Manual Setup Mode** for the recovery method.
4. Continue with the flash operation.

### Flash Process

- Flash progress can take a long time (up to **25 minutes**).
- If a time-warning dialog appears, click **Continue** and wait a bit longer.

## Detach the USB Connection

Once the flash process is complete, detach the USB by running the following command from Windows PowerShell:

```powershell
usbipd.exe detach --busid=<BUSID>
```

# OpenUI
[open-webui ](https://github.com/open-webui/open-webui)
docker run -d -p 3000:8080 --gpus all --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:cuda

## compose
```yaml
version: "3.8"

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:cuda
    container_name: open-webui
    restart: always
    ports:
      - "3000:8080"
    volumes:
      - open-webui:/app/backend/data
    extra_hosts:
      - "host.docker.internal:host-gateway"
    runtime: nvidia  # ✅ Spécifie le runtime requis pour GPU Jetson
    environment:
      - NVIDIA_VISIBLE_DEVICES=all  # ✅ Optionnel mais recommandé
      - NVIDIA_DRIVER_CAPABILITIES=all  # ✅ Assure un accès complet

volumes:
  open-webui:

```
sudo docker compose up -d

# Anything LLM

## Fix Docker IPTABLE

Add the following line to the end of defconfig
CONFIG_IP_NF_RAW=m

```shell
# This command searches for the defconfig file in the /usr/src/ directory and appends CONFIG_IP_NF_RAW=m to each file it finds.
sudo find /usr/src/ -name 'defconfig' -type f -exec sh -c 'echo "CONFIG_IP_NF_RAW=m" | sudo tee -a {}' \;
```

re-build kernel 
https://docs.nvidia.com/jetson/archives/r36.4.3/DeveloperGuide/SD/Kernel/KernelCustomization.html

cd /usr/src/
marche pas


```shell
sudo apt-get update
sudo apt-get install build-essential libncurses5-dev libssl-dev bison flex libelf-dev
cd /usr/src/linux-headers-5.15.148-tegra-ubuntu22.04_aarch64/3rdparty/canonical/linux-jammy/kernel-source

sudo make menuconfig
sudo make
sudo make modules_install
sudo make install
sudo reboot
```

and destination for iptable_raw.ko is

/lib/modules/5.15.148-tegra/kernel/net/ipv4/netfilter/

$ docker --version
Docker version 28.0.1, build 068a01e

$ docker run -dit -p 80:80 --rm --name alpine alpine:latest
c2210a7f8d3be7e5326b2b3773dc0d92834f7c4db9c779ee0ee9910edf8df462

$ lsmod | grep -i iptable_raw
iptable_raw            16384  1
ip_tables              32768  3 iptable_filter,iptable_raw,iptable_nat
x_tables               45056  12 ip6table_filter,xt_conntrack,iptable_filter,ip6table_nat,xt_tcpudp,xt_addrtype,xt_nat,ip6_tables,iptable_raw,ip_tables,iptable_nat,xt_MASQUERADE


## Pull and Run
https://github.com/Mintplex-Labs/anything-llm/blob/master/docker/HOW_TO_USE_DOCKER.md

Linux: add --add-host=host.docker.internal:host-gateway to docker run command for this to resolve.

eg: Chroma host URL running on localhost:8000 on host machine needs to be http://host.docker.internal:8000 when used in AnythingLLM.

sudo docker pull mintplexlabs/anythingllm

## Mount the storage locally and run AnythingLLM in Docker
```bash
export STORAGE_LOCATION=$HOME/anythingllm && \
mkdir -p $STORAGE_LOCATION && \
touch "$STORAGE_LOCATION/.env" && \
docker run -d -p 3001:3001 \
--cap-add SYS_ADMIN \
-v ${STORAGE_LOCATION}:/app/server/storage \
-v ${STORAGE_LOCATION}/.env:/app/server/.env \
-e STORAGE_DIR="/app/server/storage" \
mintplexlabs/anythingllm
```

### Docker Compose
```yaml
version: '3.8'
services:
  anythingllm:
    image: mintplexlabs/anythingllm
    container_name: anythingllm
    ports:
    - "3001:3001"
    cap_add:
      - SYS_ADMIN
    environment:
    # Adjust for your environment
      - STORAGE_DIR=/app/server/storage
      - JWT_SECRET="make this a large list of random numbers and letters 20+"
      - LLM_PROVIDER=ollama
      - OLLAMA_BASE_PATH=http://127.0.0.1:11434
      - OLLAMA_MODEL_PREF=llama2
      - OLLAMA_MODEL_TOKEN_LIMIT=4096
      - EMBEDDING_ENGINE=ollama
      - EMBEDDING_BASE_PATH=http://127.0.0.1:11434
      - EMBEDDING_MODEL_PREF=nomic-embed-text:latest
      - EMBEDDING_MODEL_MAX_CHUNK_LENGTH=8192
      - VECTOR_DB=lancedb
      - WHISPER_PROVIDER=local
      - TTS_PROVIDER=native
      - PASSWORDMINCHAR=8
      # Add any other keys here for services or settings
      # you can find in the docker/.env.example file
    volumes:
      - anythingllm_storage:/app/server/storage
    restart: always

volumes:
  anythingllm_storage:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/on/local/disk
```

# Listing all files for prompt

Solution depuis le Jetson:
https://github.com/jetsonhacks/jetson-orin-kernel-builder/tree/main

J'utilise la version 22.04 d'ubuntu sur un pc classique avec le sdkmanager de nvidia. 
Je possède  un Jetson AGX Orin [64GB developer kit version], P3701-0005 module, P3737-0000 carrier board avec le JetPack 6.2 installé dessus. 
Je souhaite utiliser le disque NVME de 2to en principal
Je ne veux pas utiliser de temps réel.
je souhaite flash un kernel spécifique tag "rel-36_eng_2025-02-28"

Voilà mes variables :
export TOOLCHAIN_PATH=~/l4t-gcc/aarch64--glibc--stable-2022.08-1
export CROSS_COMPILE=$TOOLCHAIN_PATH/bin/aarch64-buildroot-linux-gnu-
export NVIDIA_INSTALL_PATH=~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS
export INSTALL_MOD_PATH=$NVIDIA_INSTALL_PATH/Linux_for_Tegra/rootfs/
export KERNEL_SRC=$NVIDIA_INSTALL_PATH/Linux_for_Tegra/source/kernel/kernel-jammy-src
export KERNEL_HEADERS=$KERNEL_SRC

Utilise les procédures et l'arborescence des sources jointes au projet.

La configuration est ici : $KERNEL_SRC/arch/arm64/configs/defconfig

Voici **toutes les étapes** pour compiler et flasher un **kernel personnalisé (`rel-36_eng_2025-02-28`)** sur un **Jetson Orin NX 64GB** avec rootfs sur un **NVMe de 2 To**, **sans temps réel**, en utilisant **JetPack 6.2**.

---

## 🔧 Étapes complètes

### 0. 📥 Préparer les variables d'environnement

```bash
export TOOLCHAIN_PATH=~/l4t-gcc/aarch64--glibc--stable-2022.08-1
export CROSS_COMPILE=$TOOLCHAIN_PATH/bin/aarch64-buildroot-linux-gnu-
export NVIDIA_INSTALL_PATH=~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS
export INSTALL_MOD_PATH=$NVIDIA_INSTALL_PATH/Linux_for_Tegra/rootfs/
export KERNEL_SRC=$NVIDIA_INSTALL_PATH/Linux_for_Tegra/source/kernel/kernel-jammy-src
```

### 1. 📥 Synchroniser les sources du noyau

```bash
cd $NVIDIA_INSTALL_PATH/Linux_for_Tegra/source
./source_sync.sh -k -t rel-36_eng_2025-02-28
```

Cela crée les sources du kernel dans :

```bash
$KERNEL_SRC  # soit ~/nvidia/.../source/kernel/kernel-jammy-src
```

---

### 2. ⚙️ Compiler le kernel et ses modules

```bash
cd $KERNEL_SRC

# Configuration de base
make O=../build ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE defconfig

# Compilation
make -j$(nproc) O=../build ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE
sudo -E make install -C kernel

# Copier l’image du kernel compilé
cp $KERNEL_SRC/../build/arch/arm64/boot/Image $NVIDIA_INSTALL_PATH/Linux_for_Tegra/kernel/Image
```

---

### 3. 📦 Installer les modules dans le rootfs

```bash
sudo -E make O=../build ARCH=arm64 INSTALL_MOD_PATH=$INSTALL_MOD_PATH modules_install
```

---

### 4.1 📦 Building the DTBs

Go to the build directory:

```bash
cd $KERNEL_SRC
make O=../build ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE dtbs
```

Run the following commands to install:

```bash
cp $KERNEL_SRC/../build/arch/arm64/boot/dts/nvidia/*.dtb $NVIDIA_INSTALL_PATH/Linux_for_Tegra/kernel/dtb/
```

### 4.2 📦 Mettre à jour l'initrd

```bash
cd $NVIDIA_INSTALL_PATH/Linux_for_Tegra
sudo ./tools/l4t_update_initrd.sh
```




---

### 5. 🚀 Flasher le Jetson Orin NX avec le NVMe comme rootfs

> ⚠️ Le Jetson doit être en **mode recovery**, branché en USB-C

```bash
cd $NVIDIA_INSTALL_PATH/Linux_for_Tegra

sudo BOARDID=3701 BOARDSKU=0005 FAB=000 \
  ./tools/kernel_flash/l4t_initrd_flash.sh \
  -c tools/kernel_flash/flash_l4t_t234_nvme.xml \
  --external-device nvme0n1p1 \
  --direct nvme0n1 \
  --showlogs \
  jetson-agx-orin-devkit external
```

> Le nom de config `jetson-orin-nano-devkit` est valide pour **Orin NX sur carte P3767**.  
> Vérifie avec `ls Linux_for_Tegra/*.conf` si un lien symbolique pointe vers `p3767-0000` (ce qui est le cas ici).

---

### 6. ✅ Vérification post-flash

Une fois redémarré :

```bash
# Vérifie que le rootfs est bien sur NVMe
df -h /

# Vérifie le kernel en cours
uname -a
```

Tu devrais voir un noyau avec une date proche de fin février 2025 (correspondant au tag).

---

Souhaites-tu que je t'en fasse un **script `.sh` prêt à exécuter**, basé sur ça ?





~/build_and_flash_kernel.sh
```shell
echo '$ sudo tree -a -L 3 ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra' > ~/Téléchargements/arborescence_Linux_for_Tegra.txt && \
sudo tree -a -L 3 ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra >> ~/Téléchargements/arborescence_Linux_for_Tegra.txt
```
voici ci-joint l'arborecence des sources.
je souhaite flash un kernel spécifique tag "rel-36_eng_2025-02-28"

```shell
echo '$ sudo find ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra' > ~/Téléchargements/contenu_Linux_for_Tegra.txt && \
sudo find ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra >> ~/Téléchargements/contenu_Linux_for_Tegra.txt
```

# Fix Kernel for Docker then Flash Orin AGX
```shell
sudo apt install git-core build-essential bc
```
Finding last tag here https://nv-tegra.nvidia.com/r/gitweb?p=3rdparty/canonical/linux-jammy.git;a=summary
then sync
```shell
cd ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra/source
./source_sync.sh -k -t rel-36_eng_2025-02-28

./source_sync.sh -k -t l4t-l4t-r36.4.4_eng_2025-04-02
```

# Building the Jetson Linux Kernel

```shell
export TOOLCHAIN_PATH=/home/lamplis/l4t-gcc/aarch64--glibc--stable-2022.08-1
export NVIDIA_INSTALL_PATH=/home/lamplis/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS
export KERNEL_SRC=kernel/kernel-5.10
```
Jetson Linux Toolchain https://docs.nvidia.com/jetson/archives/r36.2/DeveloperGuide/AT/JetsonLinuxDevelopmentTools.html
Extracting the Toolchain

To extract the toolchain, enter these commands:
```shell
$ mkdir $HOME/l4t-gcc
$ cd $HOME/l4t-gcc
$ tar xf <toolchain_archive>
# tar xf ~/Téléchargements/aarch64--glibc--stable-2022.08-1.tar.bz2
```
Setting the CROSS_COMPILE Environment Variable
```shell
//export TOOLCHAIN_PATH=/home/lamplis/l4t-gcc/aarch64--glibc--stable-2022.08-1
export CROSS_COMPILE=$HOME/l4t-gcc/aarch64--glibc--stable-2022.08-1/bin/aarch64-buildroot-linux-gnu-
```
https://docs.nvidia.com/jetson/archives/r36.2/DeveloperGuide/SD/Kernel/KernelCustomization.html#building-the-jetson-linux-kernel
Building the Jetson Linux Kernel

    Go to the build directory:
    <install-path> = NVIDIA_INSTALL_PATH= /home/lamplis/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS
```shell
export NVIDIA_INSTALL_PATH=/home/lamplis/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS
cd $NVIDIA_INSTALL_PATH/Linux_for_Tegra/source
=>    ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra/source
```

```shell
// <toolchain-path> = /home/lamplis/l4t-gcc/aarch64--glibc--stable-2022.08-1/
// export CROSS_COMPILE=<toolchain-path>/bin/aarch64-buildroot-linux-gnu-
sudo apt-get install flex bison libssl-dev

make -C kernel
```
Run the following commands to install the kernel and in-tree modules:

```shell
export INSTALL_MOD_PATH=$NVIDIA_INSTALL_PATH/Linux_for_Tegra/rootfs/
sudo -E make install -C kernel
cp kernel/kernel-jammy-src/arch/arm64/boot/Image \
  $NVIDIA_INSTALL_PATH/Linux_for_Tegra/kernel/Image
```
# Building the NVIDIA Out-of-Tree Modules



    Go to the build directory:
```shell
cd $NVIDIA_INSTALL_PATH/Linux_for_Tegra/source
```

    Run the following commands to build:
```shell
export CROSS_COMPILE=$TOOLCHAIN_PATH/bin/aarch64-buildroot-linux-gnu-
export KERNEL_HEADERS=$PWD/kernel/kernel-jammy-src
make modules
```

    Run the following commands to install:

```shell
export INSTALL_MOD_PATH=$NVIDIA_INSTALL_PATH/Linux_for_Tegra/rootfs/
sudo -E make modules_install
```

# Building the DTBs

    Go to the build directory:

```shell
cd ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra/source/kernel/kernel-jammy-src
make ARCH=arm64 defconfig scripts

cd $NVIDIA_INSTALL_PATH/Linux_for_Tegra/source
```

    Run the following commands to build:
```shell
export CROSS_COMPILE=$TOOLCHAIN_PATH/bin/aarch64-buildroot-linux-gnu-
export KERNEL_HEADERS=$PWD/kernel/kernel-jammy-src
make dtbs
```
    Run the following commands to install:

```shell
cp nvidia-oot/device-tree/platform/generic-dts/dtbs/* \
         $NVIDIA_INSTALL_PATH/Linux_for_Tegra/kernel/dtb/
```


/bin/bash -c /home/lamplis/.nvsdkm/replays/scripts/JetPack_6.2_Linux/NV_L4T_FLASH_JETSON_LINUX_COMP.sh

# how to flash a custom or specific tag (e.g., rel-36_eng_2025-02-28)

To flash a custom or specific tag (e.g., `rel-36_eng_2025-02-28`) onto your NVIDIA Jetson device, you can use the `flash.sh` script provided in the Jetson Linux package. Here's a step-by-step guide:

---

### 1. **Prepare Your Environment**
   - Ensure you have the required tools installed on your host machine:
     ```bash
     sudo apt-get install build-essential libncurses5-dev libssl-dev
     ```
   - Download and install the NVIDIA SDK Manager if you haven't already. It simplifies the setup process.

---

### 2. **Sync the Specific Tag**
   - Navigate to the `Linux_for_Tegra/source` directory:
     ```bash
     cd ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra/source
     ```
   - Sync the source code to the desired tag:
     ```bash
     ./source_sync.sh -k -t rel-36_eng_2025-02-28
     ```

---

### 3. **Build the Kernel and Device Tree**
   - Navigate to the kernel source directory:
     ```bash
     cd kernel/kernel-jammy-src
     ```
   - Set up the default configuration:
     ```bash
     make ARCH=arm64 tegra_defconfig
     ```
   - Build the kernel, DTBs, and modules:
     ```bash
     make ARCH=arm64 -j$(nproc)
     make ARCH=arm64 dtbs
     make ARCH=arm64 modules
     ```

---

### 4. **Replace Kernel and DTBs**
   - Copy the kernel image and DTBs to the `Linux_for_Tegra` directory:
     ```bash
     cp arch/arm64/boot/Image ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra/kernel/
     cp arch/arm64/boot/dts/nvidia/*.dtb ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra/kernel/dtb/
     ```

### 5. **Flash the Device**
   - Put your Jetson device into recovery mode:
     - Hold the **RECOVERY** button while powering on the device.
   - Flash the device using the `flash.sh` script:
```bash
     cd ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra
     sudo ./flash.sh jetson-agx-orin-devkit mmcblk0p1

     sudo ./flash.sh jetson-agx-orin-devkit nvme0n1p1
```
NVIDIA provides an alternative script, l4t_initrd_flash.sh, which simplifies flashing to external storage like NVMe:
```bash
sudo ./tools/l4t_initrd_flash.sh --external-device nvme0n1p1 -c ./tools/kernel_flash/flash_l4t_external.xml jetson-agx-orin-devkit nvme0n1p1
```

### 6. **Verify the Flash**
   - Once the flashing process is complete, reboot the device and verify that the custom tag has been applied.

---
# Docker ISSUE

## ✅ **1. Vérifier la version actuelle de Jetson Linux**
Avant de commencer, assurez-vous de connaître votre version de **L4T (Linux for Tegra)** :

```bash
dpkg-query --show nvidia-l4t-core
```
Exemple de sortie :
```
nvidia-l4t-core  36.4.3-20250107174145
```
Si votre version est compatible avec le tag que vous voulez (`rel-36_eng_2025-02-28`), vous pouvez continuer.

---

## 📥 **2. Récupérer les sources du noyau via Git**
NVIDIA héberge les sources du noyau sur son serveur Git. Voici comment récupérer **le tag spécifique** :

1. **Installez Git et les outils nécessaires** :
   ```bash
   sudo apt update
   sudo apt install git build-essential bc bison flex libssl-dev libelf-dev libncurses5-dev
   ```

2. **Créez un dossier de travail et accédez-y** :
   ```bash
   mkdir -p ~/jetson-kernel && cd ~/jetson-kernel
   ```

3. **Clonez le dépôt du noyau NVIDIA :**
liste des tags ici : https://nv-tegra.nvidia.com/r/gitweb?p=3rdparty/canonical/linux-jammy.git;a=summary
```
git clone --depth 1 --branch rel-36_eng_2025-02-28 https://nv-tegra.nvidia.com/r/3rdparty/canonical/linux-jammy.git
git clone --branch rel-36_eng_2025-02-28 https://nv-tegra.nvidia.com/3rdparty/canonical/linux-jammy/

```

4. **Accédez au dossier cloné :**
   ```bash
   cd linux-jammy
   ```
   
🚀 **Vous êtes maintenant sur la version exacte du noyau NVIDIA correspondant à ce tag !**

---

## ⚙️ **3. Configurer le noyau**
1. **Copiez la configuration actuelle pour ne pas repartir de zéro :**
   ```bash
   cp /proc/config.gz .
   gunzip config.gz
   mv config .config
   ```

2. **Lancer la configuration du noyau (si besoin de modifier des options) :**
   ```bash
   make ARCH=arm64 menuconfig
   ```

   - **Activer les options réseau** : `Networking Support` → `Networking Options` → Activer `iptables`, `x_tables`, `ip_tables`
   - **Vérifier les modules Tegra et stockage** si besoin.

3. **Sauvegardez et quittez** (`Exit` → `Save`).

---

## 🔨 **4. Compiler le noyau**
1. **Définir les variables d'environnement :**
   ```bash
   export ARCH=arm64
   export CROSS_COMPILE=aarch64-linux-gnu-
   ```

2. **Compiler le noyau :**
Vous êtes dans une phase où le système vous demande de confirmer certains correctifs matériels pour le noyau, connus sous le nom de ARM errata workarounds. Ces correctifs sont appliqués pour éviter des bugs matériels liés aux processeurs Cortex-A et Neoverse. Si vous utilisez un Jetson AGX Orin, qui contient des cœurs Cortex-A78AE + Cortex-A65AE, il est préférable de répondre Y (Yes) à toutes les questions pour activer les correctifs nécessaires.
   ```bash
   yes "" | make -j$(nproc)
   ```

3. **Compiler les modules uniquement si nécessaire :**
   ```bash
   make modules -j$(nproc)
   ```

---

## 📂 **5. Installer le noyau et les modules**
1. **Installer les nouveaux modules :**
   ```bash
   sudo make modules_install
   ```

2. **Installer le noyau :**
   ```bash
   sudo cp arch/arm64/boot/Image /boot/Image
   sudo cp arch/arm64/boot/dts/nvidia/*.dtb /boot/
   ```

Ensuite, redémarrez le Jetson :
```bash
sudo reboot
```
---

## 🔄 **6. Mettre à jour le bootloader**
1. **Retourner dans le dossier du bootloader :**
   ```bash
   cd ~/jetson-kernel/Linux_for_Tegra
   ```

2. **Mettre à jour le Jetson avec le nouveau noyau :**
   Par défaut, mmcblk0p1 signifie que le système va être installé dans l’eMMC interne du Jetson.
   ```bash
   sudo ./flash.sh jetson-agx-orin-devkit mmcblk0p1
   ```
   Si vous voulez installer Jetson Linux sur un SSD NVMe au lieu de l’eMMC, remplacez mmcblk0p1 par nvme0n1p1 :
   ```bash
   sudo ./flash.sh jetson-agx-orin-devkit nvme0n1p1
   ```
⚠️ **ATTENTION** : Cette commande peut modifier certaines partitions système, alors **assurez-vous d’avoir une sauvegarde avant**.

---

## 🚀 **7. Redémarrer et vérifier**
1. **Redémarrer le Jetson :**
   ```bash
   sudo reboot
   ```

2. **Vérifier que le noyau est bien à jour :**
   ```bash
   uname -r
   ```

   Il devrait afficher la version du noyau compilé.

---

## 🎯 **Résumé des étapes**
✔ **Télécharger les sources NVIDIA depuis Git**  
✔ **Basculer sur le tag `rel-36_eng_2025-02-28`**  
✔ **Configurer, compiler et installer le noyau**  
✔ **Mettre à jour le bootloader et redémarrer**  

---

### 🎉 **Votre Jetson AGX Orin utilise maintenant le noyau `rel-36_eng_2025-02-28` !** 🚀  
Si vous avez des erreurs ou des questions, partagez-les ici ! 🔥

