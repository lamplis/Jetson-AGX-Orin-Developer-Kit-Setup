# Jetson-AGX-Orin-Developer-Kit-Setup
Setup guide for Jetson AGX Orin Developer Kit using WSL2 Windows 11

# 1 Install Docker Desktop

# 2 Install ubuntu 22.04 WSL 2
[Setup for WSL2](https://docs.nvidia.com/sdk-manager/wsl-systems/index.html)

- Install Linux distributions that comply with the SDK you are about to install
-- open powershell in admin mode
-- Ensure you have the latest WSL kernel with the following command:
``` shell
wsl.exe --update
``` 
-- See a list of available distros with the following command:
``` shell
wsl --list --online
```
-- Install the required distribution by running the below command
``` shell
wsl --install -d Ubuntu-22.04
```

-- If you need to clean
``` shell
wsl --list --verbose
wsl --unregister Ubuntu-24.04
```

-- To flash a NVIDIA physical device which is connected over USB to your host Windows machine, you will need to install USBIPD. USBIPD version 4.3.0 or higher is required
``` shell
winget install --interactive --exact dorssel.usbipd-win
```

# 3 Setup the Linux Distribution Environment

- Upgrade Ubuntu
``` shell
sudo apt update && sudo apt upgrade -y
```

- Run the following command to uninstall all conflicting packages:
``` shell
 for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
```

- Set up Docker's apt repository.
``` shell
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
``` shell
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

- Verify that the installation is successful by running the hello-world image:
``` shell
sudo docker run hello-world
```

- It is recommended that you install the wslu package:
``` shell
sudo apt update && sudo apt install wslu -y
```
- Install additional recommended packages by running the below commands:
``` shell
sudo apt update && sudo apt install iputils-ping iproute2 netcat iptables dnsutils network-manager usbutils net-tools python3-yaml dosfstools libgetopt-complete-perl openssh-client binutils xxd cpio udev dmidecode -y
```
- To flash a NVIDIA device connected over USB, install the following packages by running the below commands:
``` shell
sudo apt install linux-tools-virtual hwdata
```
- Install SDK Manager, which is available from https://developer.nvidia.com/nvidia-sdk-manager.
It is recommended that you download the client via a Windows host machine browser and copy it to a WSL folder (usually available at \\wsl$). From a Linux distribution, using a network repo is the recommended method.

# 4 Flash a Jetson Device

## Run your WSL Linux distribution.

1. Connect the Jetson device to a USB port on your Windows machine.
2. Boot the Jetson device into Recovery mode.
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
usbipd.exe bind --busid <BUSID> --force
usbipd.exe attach --wsl --busid=<BUSID> --auto-attach
```

### Validate the Connection

Run the following command in WSL to ensure the Jetson device appears:

```bash
lsusb
```

## Install SDK Manager
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

## Run the SDK Manager to Flash

Using Docker :
```shell
sudo docker run -it --privileged -v /dev/bus/usb:/dev/bus/usb/ -v /dev:/dev -v /media/$USER:/media/nvidia --name JetPack_AGX_Orin_Devkit --network host sdkmanager --cli --action install --login-type devzone --product Jetson --target-os Linux --version 6.2 --target JETSON_AGX_ORIN_TARGETS --flash --license accept --stay-logged-in true --collect-usage-data enable --exit-on-finish
```

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

