# Jetson-AGX-Orin-Developer-Kit-Setup
Setup guide for Jetson AGX Orin Developer Kit using WSL2 Windows 11
Great presentation: https://docs.ultralytics.com/fr/guides/nvidia-jetson/#what-is-nvidia-jetpack

## Upgrade your clean installation
```shell
sudo apt-get update && sudo apt-get upgrade && sudo reboot
```

## Install compatible Docker for JetPack 6.2    
Thank you Jetson Hacks for this complete tutorial : https://github.com/jetsonhacks/install-docker

```shell
mkdir ~/Workspace
mkdir ~/Workspace/sources
cd ~/Workspace/sources
git clone https://github.com/jetsonhacks/install-docker.git
```

## Core Installation
Install nv-container and Docker on the rootfs
```bash
bash ./install_nvidia_docker.sh
```

## Configuration
Configure the Jetson to run Docker and take advantage of NVIDIA runtime
```bash
bash ./configure_nvidia_docker.sh
```

## Unhold and Upgrade Docker
**Important: It is not currently safe to perform this.** The Docker 28.0.0 release broke Docker on Jetson because of a dependency on kernel modules ip_set, ip_set_hash_net and netfilter_xt_set which are not set in the default Jetson kernel. The work around is to downgrade the Docker files to 27.5.1 and mark them as 'hold' so that they would not be updated when performing an apt upgrade. If you installed Docker using these scripts previously and the Docker packages were downgraded and held, you can undo the hold and upgrade using this script: 
```
bash unhold_and_upgrade_docker.sh
```
which will 'mark unhold' the held packages and upgrade them.

## Downgrade Docker
An issue with Docker 28.0.0 (released 2/20/2025) requires changes to the kernel which are not implemented in the current Jetson 6.2 release. 28.0.1 addressed the issue, but did not solve the problem. If you have Docker installed, and after an apt upgrade the Docker daemon will not run, you can downgrade to Docker 27.5.1 using the downgrade_docker.sh script:
```
bash ./downgrade_docker.sh
```
Docker is downgraded to 27.5.1 and the packages are marked hold so that apt upgrade will not upgrade them automatically.
