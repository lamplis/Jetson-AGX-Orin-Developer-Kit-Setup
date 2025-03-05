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
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

- To install the latest version, run:
```shell
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

- Verify that the installation is successful by running the hello-world image:
```shell
sudo docker run hello-world
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

