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
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:cuda
    container_name: open-webui
    restart: always
    ports:
      - "3000:8080"
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
    volumes:
      - open-webui:/app/backend/data
    extra_hosts:
      - "host.docker.internal:host-gateway"

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

# Fix Kernel for Docker then Flash Orin AGX
```
sudo apt install git-core build-essential bc
```
Finding last tag here https://nv-tegra.nvidia.com/r/gitweb?p=3rdparty/canonical/linux-jammy.git;a=summary
then sync
```
~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra/source$ ./source_sync.sh -k -t rel-36_eng_2025-02-28
```

Jetson Linux Toolchain https://docs.nvidia.com/jetson/archives/r36.2/DeveloperGuide/AT/JetsonLinuxDevelopmentTools.html
Extracting the Toolchain

To extract the toolchain, enter these commands:
```
$ mkdir $HOME/l4t-gcc
$ cd $HOME/l4t-gcc
$ tar xf <toolchain_archive>
```
Setting the CROSS_COMPILE Environment Variable
```
export CROSS_COMPILE=$HOME/l4t-gcc/aarch64--glibc--stable-2022.08-1/bin/aarch64-buildroot-linux-gnu-
```
https://docs.nvidia.com/jetson/archives/r36.2/DeveloperGuide/SD/Kernel/KernelCustomization.html#building-the-jetson-linux-kernel
Building the Jetson Linux Kernel

    Go to the build directory:
```
    $ cd <install-path>/Linux_for_Tegra/source
    ~/nvidia/nvidia_sdk/JetPack_6.2_Linux_JETSON_AGX_ORIN_TARGETS/Linux_for_Tegra/source
```
    If you are building the real-time kernel, enable the real-time configuration:
```
    $ ./generic_rt_build.sh "enable"
```
```
// export CROSS_COMPILE=<toolchain-path>/bin/aarch64-buildroot-linux-gnu-
sudo apt-get install flex bison libssl-dev

$ make -C kernel
```
