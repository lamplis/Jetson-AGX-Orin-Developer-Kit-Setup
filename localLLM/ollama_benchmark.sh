#!/bin/bash
# ------------------------------------------------------------------------------
# OLLAMA BENCHMARK SCRIPT
# ------------------------------------------------------------------------------
# This script runs a series of performance benchmarks on a given LLM model 
# using Docker containers with the NVIDIA runtime. It supports both full and
# quick benchmarking modes, and can be executed in background.
#
# Usage:
#   ./ollama_benchmark.sh [--bg] <model_name> [--speed]
#
# Examples:
#   ➤ Run full benchmark in foreground:
#     ./ollama_benchmark.sh deepseek-r1:14b-qwen-distill-q4_K_M
#
#   ➤ Run quick benchmark in background:
#     ./ollama_benchmark.sh --bg deepseek-r1:14b-qwen-distill-q4_K_M --speed
#
# Background mode:
#   --bg: Launches the benchmark in background using nohup. 
#         Logs are stored in the `logs/` directory with a timestamped filename.
#
# Speed mode:
#   --speed: Uses a reduced set of configurations for a faster test run.
#
# ------------------------------------------------------------------------------
# TESTING INSTRUCTIONS (Step-by-step)
# ------------------------------------------------------------------------------
# ▶️ STEP 1 - Run the benchmark in background
# -------------------------------------------
# ./ollama_benchmark.sh --bg deepseek-r1:14b-qwen-distill-q4_K_M --speed
#
# 🧪 STEP 2 - Monitor progress and view logs
# -------------------------------------------
# ➤ Check live logs:
#   tail -f logs/ollama_benchmark_*.log
#
# ➤ Check running Docker containers:
#   docker ps
#
# ➤ After completion, check summary file:
#   cat logs/ollama_benchmark_done.log
#
# ➤ CSV results and debug logs:
#   results_<model>/TIMESTAMP_<model>/*.csv
#   results_<model>/TIMESTAMP_<model>/logs/*.log
#
# ------------------------------------------------------------------------------


# 🕓 Timestamp for logs
NOW=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/ollama_benchmark_${NOW}.log"

mkdir -p "$LOG_DIR"

# 🏃 Background mode
if [[ "$1" == "--bg" ]]; then
  shift
  echo "🚀 Launching in background..."
  echo "📄 Log file : $LOG_FILE"
  nohup "$0" "$@" > "$LOG_FILE" 2>&1 &
  echo "📍 PID : $!"
  exit 0
fi

# 🚦 Argument validation
MODEL="$1"
MODE="$2"  # Optional: --speed

if [ -z "$MODEL" ]; then
  echo "❌ Usage: $0 [--bg] <model_name> [--speed]"
  echo ""
  echo "Examples:"
  echo "  ➤ Run full benchmark in foreground:"
  echo "    $0 deepseek-r1:14b-qwen-distill-q4_K_M"
  echo ""
  echo "  ➤ Run quick benchmark in background:"
  echo "    $0 --bg deepseek-r1:14b-qwen-distill-q4_K_M --speed"
  exit 1
fi

# 🔧 Runtime parameters
IMAGE="dustynv/ollama:r36.4.0-cu128-24.04"
PROMPT="Explique brièvement le principe de la gravité quantique."
N_PREDICT=50
HOST_PORT=9000

TIMESTAMP=$(date +%Y%m%d_%H%M)
DATE_PREFIX=$(date +%Y%m%d)

MODEL_ID_SAFE="${MODEL//[:]/_}"
BASE_DIR="results_${MODEL_ID_SAFE}/${TIMESTAMP}_${MODEL_ID_SAFE}"
LOG_CSV="$BASE_DIR/${TIMESTAMP}_${MODEL_ID_SAFE}_benchmark.csv"
DEBUG_LOG_DIR="$BASE_DIR/logs"
mkdir -p "$DEBUG_LOG_DIR"

echo "model;context_len;prefill_chunk;batch_size;kv_cache_type;gpu_layers;threads;avg_time_s;status" > "$LOG_CSV"

# 💡 Set benchmarking configurations
if [ "$MODE" == "--speed" ]; then
  CONTEXT_LENS=(1024)
  PREFILL_CHUNKS=(64)
  BATCH_SIZES=(1)
  KV_CACHE_TYPES=("q4")
  GPU_LAYERS=(4)
  THREADS=(6)
else
  CONTEXT_LENS=(1024 4096 8192)
  PREFILL_CHUNKS=(64 256 512)
  BATCH_SIZES=(1)
  KV_CACHE_TYPES=("q4" "f16")
  GPU_LAYERS=(4 16 32)
  THREADS=(6 12 24)
fi

# 🧪 Start benchmark loop
for kv in "${KV_CACHE_TYPES[@]}"; do
  for batch in "${BATCH_SIZES[@]}"; do
    for context in "${CONTEXT_LENS[@]}"; do
      for chunk in "${PREFILL_CHUNKS[@]}"; do
        for threads in "${THREADS[@]}"; do
          for layers in "${GPU_LAYERS[@]}"; do

            CONTAINER_NAME="ollama-bench-$context-$chunk-$batch-$kv-$layers"
            docker rm -f "$CONTAINER_NAME" &>/dev/null || true

            echo ""
            echo "🚀 Test: CONTEXT=$context | CHUNK=$chunk | BATCH=$batch | KV=$kv | GPU_LAYERS=$layers"

	    echo "docker run -d -p $HOST_PORT:9000 --name '$CONTAINER_NAME' \
              --runtime nvidia \
              -e OLLAMA_PRELOAD_MODELS=$MODEL \
              -e OLLAMA_MODELS=/root/.ollama \
              -e OLLAMA_CONTEXT_LEN=$context \
              -e OLLAMA_PREFILL_CHUNK_SIZE=$chunk \
              -e OLLAMA_MAX_BATCH_SIZE=$batch \
              -e OLLAMA_KV_CACHE_TYPE=$kv \
              -e OLLAMA_NUM_GPU_LAYERS=$layers \
              -e OLLAMA_NUM_THREADS=$threads \
              -e OLLAMA_MAX_LOADED_MODELS=1 \
              -e OLLAMA_HOST=0.0.0.0:9000 \
              -e OLLAMA_FLASH_ATTENTION=true \
              -e OLLAMA_DEBUG=false \
              -e HF_TOKEN='$HF_TOKEN' \
              -e HF_HUB_CACHE=/root/.cache/huggingface \
              -v /mnt/nvme/cache/ollama:/root/.ollama \
              -v /mnt/nvme/cache:/root/.cache \
              -v /dev:/dev -v /tmp:/tmp \
              -v /var/run/docker.sock:/var/run/docker.sock \
              -v /etc/localtime:/etc/localtime:ro \
              -v /etc/timezone:/etc/timezone:ro \
              -v /run/jtop.sock:/run/jtop.sock \
              '$IMAGE' ollama serve"
              
            # 🐳 Launch container
            CONTAINER_ID=$(docker run -d -p $HOST_PORT:9000 --name "$CONTAINER_NAME" \
              --runtime nvidia \
              -e OLLAMA_PRELOAD_MODELS=$MODEL \
              -e OLLAMA_MODELS=/root/.ollama \
              -e OLLAMA_CONTEXT_LEN=$context \
              -e OLLAMA_PREFILL_CHUNK_SIZE=$chunk \
              -e OLLAMA_MAX_BATCH_SIZE=$batch \
              -e OLLAMA_KV_CACHE_TYPE=$kv \
              -e OLLAMA_NUM_GPU_LAYERS=$layers \
              -e OLLAMA_NUM_THREADS=$threads \
              -e OLLAMA_MAX_LOADED_MODELS=1 \
              -e OLLAMA_HOST=0.0.0.0:9000 \
              -e OLLAMA_FLASH_ATTENTION=true \
              -e OLLAMA_DEBUG=false \
              -e HF_TOKEN="$HF_TOKEN" \
              -e HF_HUB_CACHE=/root/.cache/huggingface \
              -v /mnt/nvme/cache/ollama:/root/.ollama \
              -v /mnt/nvme/cache:/root/.cache \
              -v /dev:/dev -v /tmp:/tmp \
              -v /var/run/docker.sock:/var/run/docker.sock \
              -v /etc/localtime:/etc/localtime:ro \
              -v /etc/timezone:/etc/timezone:ro \
              -v /run/jtop.sock:/run/jtop.sock \
              "$IMAGE" ollama serve)

            sleep 5

            # ❌ Crash detection
            if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
              LOGFILE="$DEBUG_LOG_DIR/${DATE_PREFIX}-$context-$chunk-$batch-$kv-$layers.log"
              docker logs "$CONTAINER_NAME" &> "$LOGFILE" || echo "⚠️ Failed to fetch logs." >> "$LOGFILE"
              echo "$context;$chunk;$batch;$kv;$layers;$threads;-1;CRASH" >> "$LOG_CSV"
              docker stop "$CONTAINER_NAME" &>/dev/null || true
              docker rm -f "$CONTAINER_NAME" &>/dev/null || true
              docker rmi -f "$IMAGE" 2>/dev/null || true
              continue
            fi

            # ⏳ Wait for API readiness
            for i in {1..30}; do
              curl -s http://localhost:$HOST_PORT/v1/models > /dev/null && break
              sleep 2
            done

            # ⏱️ Run 3 test requests and compute average
            TIMES=()
            for i in 1 2 3; do
              START=$(date +%s)
              curl -s -X POST http://localhost:$HOST_PORT/api/generate \
                -H "Content-Type: application/json" \
                -d '{"model":"'"$MODEL"'","prompt":"'"$PROMPT"'","n_predict":'"$N_PREDICT"',"stream":false}' > /dev/null
              END=$(date +%s)
              TIMES+=($((END - START)))
            done

            docker stop "$CONTAINER_NAME" > /dev/null

            TOTAL=0
            for t in "${TIMES[@]}"; do TOTAL=$((TOTAL + t)); done
            AVG=$((TOTAL / 3))

            STATUS="OK"
            if [ "$AVG" -gt 30 ]; then STATUS="SLOW"; fi

            echo "$MODEL_ID_SAFE;$context;$chunk;$batch;$kv;$layers;$threads;$AVG;$STATUS" >> "$LOG_CSV"
          done
        done
      done
    done
  done
done

# ✅ Summary at the end
END_LOG="logs/ollama_benchmark_done.log"
echo "✅ Benchmark completed at $(date '+%Y-%m-%d %H:%M:%S') for $MODEL" >> "$END_LOG"
echo "📄 CSV results : $LOG_CSV" >> "$END_LOG"
echo "🗂️ Debug logs : $DEBUG_LOG_DIR" >> "$END_LOG"
echo "----------------------------------------" >> "$END_LOG"

echo ""
echo "✅ Benchmark completed. CSV: $LOG_CSV"
echo "📂 Debug logs: $DEBUG_LOG_DIR"
