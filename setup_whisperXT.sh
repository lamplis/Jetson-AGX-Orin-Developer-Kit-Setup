#!/bin/bash
set -e

################################################################################
# 📄 whisperxt Installer & Wrapper Setup
#
# DESCRIPTION:
# This script installs a wrapper called `whisperxt` to enhance the usage of
# `whisperx`, a powerful audio transcription tool, especially on NVIDIA Jetson
# devices (Orin, Xavier, Nano, etc.).
#
# FEATURES:
# - Automatically boosts GPU performance (`nvpmodel`, `jetson_clocks`)
# - Converts MP3 files to WAV in RAM for faster processing
# - Logs all output to timestamped log files in `./outputs/`
# - Measures and displays total execution time
# - Emits a terminal bell on completion
#
# USAGE:
# After running this script once:
#   whisperxt --diarize --model large-v3 --language fr path/to/audio.mp3
#
# LOGS:
# - Logs are saved to: ./outputs/whisperx_<timestamp>.log
#
# NOTE:
# - Requires `ffmpeg`, `whisperx`, and sudo rights for Jetson power settings.
################################################################################

echo "🛠️ Setting up whisperxt wrapper..."

# Create user bin and log directories if they don't exist
mkdir -p ~/.local/bin
mkdir -p ~/Workspace/whisperx_logs

# Define whisperxt wrapper
cat > ~/.local/bin/whisperxt << 'EOF'
#!/bin/bash
set -e

# Check if whisperx is installed
if ! command -v whisperx &> /dev/null; then
  echo "❌ whisperx not found in PATH. Please install it before running this script."
  exit 1
fi

# Create output directory for logs
LOG_DIR="./outputs"
mkdir -p "$LOG_DIR"

# Create a timestamped log file
LOG_FILE="$LOG_DIR/whisperx_$(date '+%Y%m%d_%H%M%S').log"

# Start timer
START_TIME=$(date +%s)
echo "🕒 Running whisperx transcription..." | tee "$LOG_FILE"

# === GPU cleanup and performance boost ===
echo "[INFO] Setting Jetson to max performance mode..." | tee -a "$LOG_FILE"
sudo nvpmodel -m 0 >> "$LOG_FILE" 2>&1 || echo "[WARN] Failed to set nvpmodel" | tee -a "$LOG_FILE"
sudo jetson_clocks >> "$LOG_FILE" 2>&1 || echo "[WARN] Failed to set jetson_clocks" | tee -a "$LOG_FILE"

echo "[INFO] Attempting to release GPU memory if occupied..." | tee -a "$LOG_FILE"
sudo fuser -v /dev/nvhost-ctrl >> "$LOG_FILE" 2>&1 || echo "[WARN] No process to free on /dev/nvhost-ctrl" | tee -a "$LOG_FILE"

# === Preprocessing: convert MP3 to WAV in RAM if needed ===
INPUT_FILE="${!#}"  # Last argument = input audio
EXT="${INPUT_FILE##*.}"

if [[ "$EXT" == "mp3" ]]; then
  BASENAME=$(basename "$INPUT_FILE" .mp3)
  RAM_WAV="/dev/shm/${BASENAME}.wav"

  if [[ ! -f "$RAM_WAV" || "$INPUT_FILE" -nt "$RAM_WAV" ]]; then
    echo "[INFO] Converting $INPUT_FILE to RAM WAV: $RAM_WAV" | tee -a "$LOG_FILE"
    ffmpeg -y -i "$INPUT_FILE" -ac 1 -ar 16000 -f wav "$RAM_WAV" >> "$LOG_FILE" 2>&1
  else
    echo "[INFO] Using existing RAM WAV: $RAM_WAV" | tee -a "$LOG_FILE"
  fi

  set -- "${@:1:$(($#-1))}" "$RAM_WAV"
  CLEANUP_WAV="$RAM_WAV"
fi

# Run whisperx and log output
whisperx "$@" 2>&1 | tee -a "$LOG_FILE"

# Remove temporary RAM file if it was created
if [[ -n "$CLEANUP_WAV" && -f "$CLEANUP_WAV" ]]; then
  echo "[INFO] Cleaning up $CLEANUP_WAV" | tee -a "$LOG_FILE"
  rm -f "$CLEANUP_WAV"
fi

# Timer end and duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Print result
echo -e "\n✅ Transcription complete in ${MINUTES}m${SECONDS}s" | tee -a "$LOG_FILE"
echo "📄 Log saved to: $LOG_FILE"

# Terminal bell
echo -ne "\a"
EOF

# Make the wrapper executable
chmod +x ~/.local/bin/whisperxt

echo -e "\n✅ whisperxt is now available! You can run it just like whisperx 🎙️"
echo "Try: whisperxt --help"
