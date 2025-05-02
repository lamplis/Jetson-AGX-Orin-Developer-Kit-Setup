# My personnal Installation for Ubuntu

echo "alias ll='ls -l'" >> ~/.bashrc && source ~/.bashrc

https://github.com/m-bain/whisperX

## Install PiP & HugginFace downloader
```shell
sudo apt update && sudo apt install python3-pip ffmpeg -y
pip3 install huggingface_hub[hf_xet]
```

## Install WhisperX
You have several installation options:

- Option A: Stable Release (recommended)
Install the latest stable version from PyPI:
```shell
pip install whisperx
```

- Option B: Latest Release
```shell
pip install git+https://github.com/m-bain/whisperX.git
```

## Run transcription

### Optimized for my basic laptop :

Compute type is int8 for small capacity computer.

```shell
whisperx \
  --model large-v3 \
  --diarize \
  --language fr \
  --min_speakers 2 \
  --max_speakers 2 \
  --compute_type int8 \
  --batch_size 6 \
  --output_dir ./outputs \
  --hf_token hf_XYZ \
  --align_model fast \
  'My_File.mp3'
```

### Optimized for nvidia graphic cards :

Using compute type float16 for more precision, require more ressources.

```shell
whisperx \
  --model large-v3 \
  --device cuda --device_index 0 \
  --diarize \
  --language fr \
  --min_speakers 4 --max_speakers 4 \
  --compute_type float16 \
  --threads 12 \
  --batch_size 32 \
  --output_dir ./outputs \
  --hf_token hf_XYZ \
  'My_File.mp3'
```

## Try Whisper XT
It's a wrapper to enhance the usage of `whisperx`, a powerful audio transcription tool.

### FEATURES:
 - Automatically boosts GPU performance (`nvpmodel`, `jetson_clocks`)
 - Converts MP3 files to WAV in RAM for faster processing
 - Logs all output to timestamped log files in `./outputs/`
 - Measures and displays total execution time
 - Emits a terminal bell on completion

### Install

```shell
mkdir whisperXT && cd whisperXT/ && \
wget https://raw.githubusercontent.com/lamplis/Jetson-AGX-Orin-Developer-Kit-Setup/refs/heads/main/whisperX%20/setup_whisperXT.sh && \
chmod +x setup_whisperXT.sh
```

### USAGE:
After running this script once:
```shell
whisperxt --diarize --model large-v3 --language fr path/to/audio.mp3
```
