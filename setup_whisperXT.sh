#!/bin/bash
set -e

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

# Create output directory for transcription logs
LOG_DIR="./outputs"
mkdir -p "$LOG_DIR"

# Create a unique log file with timestamp
LOG_FILE="$LOG_DIR/whisperx_$(date '+%Y%m%d_%H%M%S').log"

# Start timing
START_TIME=$(date +%s)
echo "🕒 Running whisperx transcription..." | tee "$LOG_FILE"

# === Preprocessing: Convert MP3 to RAM-based WAV if needed ===
INPUT_FILE="${!#}"  # Last argument is assumed to be the audio file
EXT="${INPUT_FILE##*.}"

if [[ "$EXT" == "mp3" ]]; then
  BASENAME=$(basename "$INPUT_FILE" .mp3)
  RAM_WAV="/dev/shm/${BASENAME}.wav"

  # Convert only if .wav is missing or outdated
  if [[ ! -f "$RAM_WAV" || "$INPUT_FILE" -nt "$RAM_WAV" ]]; then
    echo "[INFO] Converting $INPUT_FILE to RAM WAV: $RAM_WAV" | tee -a "$LOG_FILE"
    ffmpeg -y -i "$INPUT_FILE" -ac 1 -ar 16000 -f wav "$RAM_WAV" >> "$LOG_FILE" 2>&1
  else
    echo "[INFO] Using existing RAM WAV: $RAM_WAV" | tee -a "$LOG_FILE"
  fi

  # Replace the last argument with the new .wav file
  set -- "${@:1:$(($#-1))}" "$RAM_WAV"
  CLEANUP_WAV="$RAM_WAV"
fi

# Run whisperx with all given arguments and log the output
whisperx "$@" 2>&1 | tee -a "$LOG_FILE"

# Clean up the temporary .wav file in RAM if it was used
if [[ -n "$CLEANUP_WAV" && -f "$CLEANUP_WAV" ]]; then
  echo "[INFO] Cleaning up $CLEANUP_WAV" | tee -a "$LOG_FILE"
  rm -f "$CLEANUP_WAV"
fi

# Stop timing and calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Print final result
echo -e "\n✅ Transcription complete in ${MINUTES}m${SECONDS}s" | tee -a "$LOG_FILE"
echo "📄 Log saved to: $LOG_FILE"

# Terminal bell for notification
echo -ne "\a"
EOF

# Make the wrapper executable
chmod +x ~/.local/bin/whisperxt

echo -e "\n✅ whisperxt is now available! You can run it just like whisperx 🎙️"
echo "Try: whisperxt --help"
