#!/bin/bash
# ------------------------------------------------------------------------------

# OLLAMA BENCHMARK SCRIPT
# ------------------------------------------------------------------------------

# This script runs a series of performance benchmarks on a given LLM model
# using Docker containers with the NVIDIA runtime. It supports both full and
# quick benchmarking modes, and can be executed in background.

# Usage:
#   ./ollama_benchmark.sh [--bg] <model_name> [--speed]

# Examples:
#   ➤ Run full benchmark in foreground:
#     ./ollama_benchmark.sh deepseek-r1:14b-qwen-distill-q4_K_M

#   ➤ Run quick benchmark in background:
#     ./ollama_benchmark.sh --bg deepseek-r1:14b-qwen-distill-q4_K_M --speed

# ------------------------------------------------------------------------------

# ▶️ STEP 1 - Run the benchmark in background
# ./ollama_benchmark.sh --bg deepseek-r1:14b-qwen-distill-q4_K_M --speed

# 🧪 STEP 2 - Monitor progress and view logs
# tail -f "$(ls -1t results_*/**/logs/ollama_benchmark_*.log | head -n 1)"
# docker ps
# cat results_*/**/logs/ollama_benchmark_done.log

# ------------------------------------------------------------------------------

# Parse arguments: extract MODEL and --speed (skip --bg if present)
ARGS=()
MODE=""
for arg in "$@"; do
  if [[ "$arg" == "--speed" ]]; then
    MODE="--speed"
  elif [[ "$arg" != "--bg" ]]; then
    ARGS+=("$arg")
  fi
done

MODEL="${ARGS[0]}"

# Generate safe model ID for filenames and directories
MODEL_ID_SAFE=$(echo "$MODEL" | tr '[:space:]/:\\' '____' | tr -cd '[:alnum:]_-' | sed 's/_*$//')


# Create base directory and log paths
TIMESTAMP=$(date +%Y%m%d_%H%M)
DATE_PREFIX=$(date +%Y%m%d)
BASE_DIR="results_${MODEL_ID_SAFE}/${TIMESTAMP}_${MODEL_ID_SAFE}"
DEBUG_LOG_DIR="$BASE_DIR/logs"
mkdir -p "$DEBUG_LOG_DIR"

NOW=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$DEBUG_LOG_DIR/ollama_benchmark_${NOW}.log"

# 🚀 Handle --bg mode before any output
if [[ "$1" == "--bg" ]]; then
  shift
  echo "🚀 Launching in background..."
  echo "📄 Log file: $LOG_FILE"
  nohup "$0" "$@" > "$LOG_FILE" 2>&1 &
  echo "📍 PID: $!"
  exit 0
fi

# Validate input
if [[ -z "$MODEL" || "$MODEL" == --* ]]; then
  echo "❌ Invalid or missing model name."
  echo ""
  echo "Usage:"
  echo "  $0 [--bg] <model_name> [--speed]"
  echo ""
  echo "Examples:"
  echo "  ➤ Run full benchmark in foreground:"
  echo "    $0 deepseek-r1:14b-qwen-distill-q4_K_M"
  echo ""
  echo "  ➤ Run quick benchmark in background:"
  echo "    $0 --bg deepseek-r1:14b-qwen-distill-q4_K_M --speed"
  exit 1
fi

# Runtime configuration
IMAGE="dustynv/ollama:r36.4.0-cu128-24.04"
PROMPTS=(
  "Décris en détail le fonctionnement d’un cerveau humain, depuis la perception d’un stimulus visuel jusqu’à la formulation d’une réponse verbale."
  "Raconte l’histoire de la conquête spatiale de 1950 à 2050 comme si c’était un roman d’anticipation."
  "Imagine un monde où l’humanité a abandonné toutes les énergies fossiles. Décris la transition énergétique, les impacts géopolitiques, économiques et sociétaux en détail."
)

N_PREDICT=50
HOST_PORT=9000

LOG_CSV="$BASE_DIR/${TIMESTAMP}_${MODEL_ID_SAFE}_benchmark.csv"
echo "model;context_len;prefill_chunk;batch_size;kv_cache_type;gpu_layers;threads;prompt1_s;prompt2_s;prompt3_s;avg_time_s;status" > "$LOG_CSV"







# 💡 Set benchmarking configurations
if [ "$MODE" == "--speed" ]; then
  CONTEXT_LENS=(1024)
  PREFILL_CHUNKS=(64)
  BATCH_SIZES=(1)
  KV_CACHE_TYPES=("f16")
  GPU_LAYERS=(4)
  THREADS=(12)
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
        for layers in "${GPU_LAYERS[@]}"; do
          for threads in "${THREADS[@]}"; do

            # Clean Containers
            echo 'Clean containers :"docker ps -a --filter "name=^/ollama-bench-" --format "{{.ID}}'
            CONTAINERS=$(docker ps -a --filter "name=^/ollama-bench-" --format "{{.ID}}")
            echo "🗑️ Containers to remove: $CONTAINERS"
            [ -n "$CONTAINERS" ] && echo "$CONTAINERS" | xargs docker rm -f

            CONTAINER_NAME="ollama-bench-$context-$chunk-$batch-$kv-$layers-$threads"


            echo ""
            echo "🚀 Test: CONTEXT=$context | CHUNK=$chunk | BATCH=$batch | KV=$kv | GPU_LAYERS=$layers | THREADS=$threads"

            echo "docker run -d -p $HOST_PORT:9000 --name '$CONTAINER_NAME' \\n
              --runtime nvidia \\n
              -e OLLAMA_PRELOAD_MODELS=$MODEL \\n
              -e OLLAMA_MODELS=/root/.ollama \\n
              -e OLLAMA_CONTEXT_LEN=$context \\n
              -e OLLAMA_PREFILL_CHUNK_SIZE=$chunk \\n
              -e OLLAMA_MAX_BATCH_SIZE=$batch \\n
              -e OLLAMA_KV_CACHE_TYPE=$kv \\n
              -e OLLAMA_NUM_GPU_LAYERS=$layers \\n
              -e OLLAMA_NUM_THREADS=$threads \\n
              -e OLLAMA_MAX_LOADED_MODELS=1 \\n
              -e OLLAMA_HOST=0.0.0.0:9000 \\n
              -e OLLAMA_FLASH_ATTENTION=true \\n
              -e OLLAMA_DEBUG=false \\n
              -e HF_TOKEN='$HF_TOKEN' \\n
              -e HF_HUB_CACHE=/root/.cache/huggingface \\n
              -v /mnt/nvme/cache/ollama:/root/.ollama \\n
              -v /mnt/nvme/cache:/root/.cache \\n
              -v /dev:/dev -v /tmp:/tmp \\n
              -v /var/run/docker.sock:/var/run/docker.sock \\n
              -v /etc/localtime:/etc/localtime:ro \\n
              -v /etc/timezone:/etc/timezone:ro \\n
              -v /run/jtop.sock:/run/jtop.sock \\n
              '$IMAGE' ollama serve\n"

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
              echo "❌ Crash detected : $CONTAINER_NAME"
              echo docker logs "$CONTAINER_NAME"
              LOGFILE="$DEBUG_LOG_DIR/${DATE_PREFIX}-$context-$chunk-$batch-$kv-$layers-$threads.log"
              docker logs "$CONTAINER_NAME" &> "$LOGFILE" || echo "⚠️ Failed to fetch logs." >> "$LOGFILE"
              echo "$MODEL_ID_SAFE;$context;$chunk;$batch;$kv;$layers;$threads;-1;-1;-1;-1;CRASH" >> "$LOG_CSV"
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
            for i in "${!PROMPTS[@]}"; do
              PROMPT="${PROMPTS[$i]}"
              echo "⏱️ Running test request $((i+1)) with prompt: ${PROMPT:0:50}..."
              START=$(date +%s)
              curl -s -X POST http://localhost:$HOST_PORT/api/generate \
                -H "Content-Type: application/json" \
                -d '{"model":"'"$MODEL"'","prompt":"'"$PROMPT"'","n_predict":'"$N_PREDICT"',"stream":false}' > /dev/null
              END=$(date +%s)
              TIMES+=($((END - START)))
            done
            PROMPT1_TIME=${TIMES[0]}
            PROMPT2_TIME=${TIMES[1]}
            PROMPT3_TIME=${TIMES[2]}


            docker stop "$CONTAINER_NAME" > /dev/null

            TOTAL=0
            for t in "${TIMES[@]}"; do TOTAL=$((TOTAL + t)); done
            AVG=$((TOTAL / 3))

            STATUS="OK"
            if [ "$AVG" -gt 30 ]; then STATUS="SLOW"; fi

            echo "$MODEL_ID_SAFE;$context;$chunk;$batch;$kv;$layers;$threads;$PROMPT1_TIME;$PROMPT2_TIME;$PROMPT3_TIME;$AVG;$STATUS" >> "$LOG_CSV"

          done
        done
      done
    done
  done
done

# ✅ Summary at the end
END_LOG="$DEBUG_LOG_DIR/ollama_benchmark_done.log"
echo "✅ Benchmark completed at $(date '+%Y-%m-%d %H:%M:%S') for $MODEL" >> "$END_LOG"
echo "📄 CSV results : $LOG_CSV" >> "$END_LOG"
echo "🗂️ Debug logs : $DEBUG_LOG_DIR" >> "$END_LOG"
echo "----------------------------------------" >> "$END_LOG"

echo ""
echo "✅ Benchmark completed. CSV: $LOG_CSV"
echo "📂 Debug logs: $DEBUG_LOG_DIR"
