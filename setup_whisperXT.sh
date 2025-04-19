#!/bin/bash
set -e

echo "🛠️ Setting up whisperxt wrapper..."

# Create local bin directory if it doesn't exist
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

# Create output directory
LOG_DIR="./outputs"
mkdir -p "$LOG_DIR"

# Create log file
LOG_FILE="$LOG_DIR/whisperx_$(date '+%Y%m%d_%H%M%S').log"

# Start timer
START_TIME=$(date +%s)
echo "🕒 Running whisperx transcription..." | tee "$LOG_FILE"

# Run whisperx and capture logs
whisperx "$@" 2>&1 | tee -a "$LOG_FILE"

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Print result
echo -e "\n✅ Transcription complete in ${MINUTES}m${SECONDS}s" | tee -a "$LOG_FILE"
echo "📄 Log saved to: $LOG_FILE"

# Notification (terminal beep)
echo -ne "\a"
EOF

# Make it executable
chmod +x ~/.local/bin/whisperxt

echo -e "\n✅ whisperxt is now available! You can run it just like whisperx 🎙️"
echo "Try: whisperxt --help"
