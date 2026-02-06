#!/bin/bash
# Soubor: compare-ollama-vs-cpp.sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Testovací prompt (delší = lepší test)
TEST_PROMPT="Explain in detail how Kubernetes networking works, including CNI plugins, pod-to-pod communication, and service discovery mechanisms."

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  SROVNÁNÍ RYCHLOSTI: Ollama vs llama.cpp  ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Zjištění počtu fyzických jader
PHYSICAL_CORES=$(grep "^cpu cores" /proc/cpuinfo | uniq | awk '{print $4}')
if [ -z "$PHYSICAL_CORES" ]; then
    PHYSICAL_CORES=$(($(nproc) / 2))
fi

echo "Používám $PHYSICAL_CORES vláken pro oba testy."
echo ""

# ===== TEST 1: OLLAMA =====
echo -e "${GREEN}[1/2] Testuji Ollama...${NC}"
echo "Prompt: $TEST_PROMPT"
echo ""

# Spustíme ollama s kontrolou vláken a měříme čas
OLLAMA_NUM_THREADS=$PHYSICAL_CORES ollama run qwen3:14b "$TEST_PROMPT"

echo ""
echo -e "${GREEN}^ Podívejte se na 'eval rate' výše${NC}"
echo ""
read -p "Stiskněte Enter pro pokračování na llama.cpp test..."

# ===== TEST 2: LLAMA.CPP =====
echo ""
echo -e "${GREEN}[2/2] Testuji llama.cpp...${NC}"
echo ""

$HOME/ai-local/llama.cpp/build/bin/llama-cli \
    -m "$HOME/ai-local/models/Qwen_Qwen3-14B-Q4_K_M.gguf" \
    -t $PHYSICAL_CORES \
    -p "$TEST_PROMPT" \
    -n 150 \
    --color auto

echo ""
echo -e "${GREEN}^ Podívejte se na 'eval time' výše${NC}"
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  SROVNÁNÍ DOKONČENO${NC}"
echo -e "${BLUE}============================================${NC}"
