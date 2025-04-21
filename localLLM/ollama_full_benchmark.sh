#!/bin/bash

# Generate a Benchmark for a specific model variating 4 parameters :
# KV_CACHE_TYPES, BATCH_SIZES, CONTEXT_LENS=(1024), PREFILL_CHUNKS=(64), GPU_LAYERS

MODEL="$1"
MODE="$2"  # Optional: "--speed"

if [ -z "$MODEL" ]; then
  echo "❌ Usage: $0 <model_name> [--speed]"
  echo "Example: $0 deepseek-r1:32b-qwen-distill-q4_K_M --speed"
  exit 1
fi

IMAGE="dustynv/ollama:r36.4.0-cu128-24.04"
PROMPT="Briefly explain the concept of quantum gravity."
N_PREDICT=50
HOST_PORT=9000

TIMESTAMP=$(date +%Y%m%d_%H%M)
DATE_PREFIX=$(date +%Y%m%d)

MODEL_ID_SAFE="${MODEL//[:]/_}"
BASE_DIR="results_${MODEL_ID_SAFE}/${TIMESTAMP}_${MODEL_ID_SAFE}"

LOG_FILE="$BASE_DIR/${TIMESTAMP}_${MODEL_ID_SAFE}_benchmark.csv"
DEBUG_LOG_DIR="$BASE_DIR/logs"
mkdir -p "$DEBUG_LOG_DIR"

echo "model,context_len,prefill_chunk,batch_size,kv_cache_type,gpu_layers,avg_time_s,status" > "$LOG_FILE"

# --speed mode = only one minimal config
if [ "$MODE" == "--speed" ]; then
  CONTEXT_LENS=(1024)
  PREFILL_CHUNKS=(64)
  BATCH_SIZES=(1)
  KV_CACHE_TYPES=("q4")
  GPU_LAYERS=(4)
else
  CONTEXT_LENS=(1024 4096 8192)
  PREFILL_CHUNKS=(64 256 512)
  BATCH_SIZES=(1)
  KV_CACHE_TYPES=("q4" "f16")
  GPU_LAYERS=(4 16 32)
fi

for kv in "${KV_CACHE_TYPES[@]}"; do
  for batch in "${BATCH_SIZES[@]}"; do
    for context in "${CONTEXT_LENS[@]}"; do
      for chunk in "${PREFILL_CHUNKS[@]}"; do
        for layers in "${GPU_LAYERS[@]}"; do
          CONTAINER_NAME="ollama-bench-$context-$chunk-$batch-$kv-$layers"
          docker rm -f "$CONTAINER_NAME" &>/dev/null || true

          echo ""
          echo "🚀 Running benchmark: CONTEXT=$context | CHUNK=$chunk | BATCH=$batch | KV=$kv | GPU_LAYERS=$layers"
          echo "🔧 Environment: CONTEXT=$context, CHUNK=$chunk, BATCH=$batch, KV=$kv, GPU_LAYERS=$layers"

          CONTAINER_ID=$(docker run -d -p $HOST_PORT:9000 --name "$CONTAINER_NAME" \
            --runtime nvidia \
            -e OLLAMA_PRELOAD_MODELS=$MODEL \
            -e OLLAMA_MODELS=/root/.ollama \
            -e OLLAMA_CONTEXT_LEN=$context \
            -e OLLAMA_PREFILL_CHUNK_SIZE=$chunk \
            -e OLLAMA_MAX_BATCH_SIZE=$batch \
            -e OLLAMA_KV_CACHE_TYPE=$kv \
            -e OLLAMA_NUM_GPU_LAYERS=$layers \
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

          # ✅ Check if container is alive
          if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
            echo "❌ Crash detected (CONTEXT=$context, GPU_LAYERS=$layers)"
            LOGFILE="$DEBUG_LOG_DIR/${DATE_PREFIX}-$context-$chunk-$batch-$kv-$layers-$MODEL_ID_SAFE.log"
            docker logs "$CONTAINER_NAME" &> "$LOGFILE" || echo "⚠️ Unable to fetch logs." >> "$LOGFILE"
            echo "📄 Logs saved to $LOGFILE"
            echo "📌 Last lines from log:"
            tail -n 20 "$LOGFILE"
            echo "$MODEL_ID_SAFE,$context,$chunk,$batch,$kv,$layers,-1,CRASH" >> "$LOG_FILE"

            echo "🛑 Forcing container stop and removal..."
            docker stop "$CONTAINER_NAME" &>/dev/null || true
            docker rm -f "$CONTAINER_NAME" &>/dev/null || true

            echo "🧹 Forcing image removal: $IMAGE"
            docker rmi -f "$IMAGE" 2>/dev/null || echo "⚠️ Image not found locally or already removed."

            continue
          fi

          # 🔁 Wait for API to respond
          for i in {1..30}; do
            curl -s http://localhost:$HOST_PORT/v1/models > /dev/null && break
            sleep 2
          done

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

          echo "$MODEL_ID_SAFE,$context,$chunk,$batch,$kv,$layers,$AVG,$STATUS" >> "$LOG_FILE"
        done
      done
    done
  done
done

echo ""
echo "✅ Benchmark finished. Results saved to $LOG_FILE"
echo "📂 Debug logs saved to $DEBUG_LOG_DIR"
