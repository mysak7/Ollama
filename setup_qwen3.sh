#!/bin/bash
set -e # Zastaví skript při jakékoliv chybě

# ==========================================
# KONFIGURACE PRO QWEN 3
# ==========================================
INSTALL_DIR="$HOME/ai-local"
# Správný název souboru z bartowski repozitáře
MODEL_FILENAME="Qwen_Qwen3-14B-Q4_K_M.gguf"

# OPRAVENÁ URL s podtržítkem ve správném názvu
MODEL_URL="https://huggingface.co/bartowski/Qwen_Qwen3-14B-GGUF/resolve/main/Qwen_Qwen3-14B-Q4_K_M.gguf?download=true"

# Barvičky pro výstup
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}   INSTALACE OPTIMALIZOVANÉHO QWEN 3 (CPU)   ${NC}"
echo -e "${BLUE}==============================================${NC}"

# 1. Instalace závislostí
echo -e "${BLUE}[1/5] Instalace systémových závislostí...${NC}"
sudo apt-get update -qq
sudo apt-get install -y build-essential cmake git curl wget

# 2. Příprava adresáře
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 3. Klonování a kompilace llama.cpp
if [ -d "llama.cpp" ]; then
    echo -e "${BLUE}[2/5] Aktualizuji existující repozitář llama.cpp...${NC}"
    cd llama.cpp
    git pull
else
    echo -e "${BLUE}[2/5] Klonuji llama.cpp...${NC}"
    git clone https://github.com/ggerganov/llama.cpp
    cd llama.cpp
fi

echo -e "${BLUE}[3/5] Kompiluji s nativní optimalizací pro CPU...${NC}"
cmake -B build -DGGML_NATIVE=ON 
cmake --build build --config Release -j$(nproc)

# 4. Stažení modelu Qwen 3
cd "$INSTALL_DIR"
mkdir -p models

if [ -f "models/$MODEL_FILENAME" ]; then
    echo -e "${GREEN}[4/5] Model $MODEL_FILENAME již existuje, přeskakuji stahování.${NC}"
else
    echo -e "${BLUE}[4/5] Stahuji Qwen 3 (cca 8.4 GB)... Jděte si pro kafe.${NC}"
    echo -e "${BLUE}URL: $MODEL_URL${NC}"
    
    # Stažení s kontrolou chyb
    if wget -O "models/$MODEL_FILENAME" "$MODEL_URL"; then
        echo -e "${GREEN}Stahování dokončeno.${NC}"
    else
        echo -e "${RED}CHYBA: Nepodařilo se stáhnout model. Zkontrolujte URL nebo internetové připojení.${NC}"
        rm -f "models/$MODEL_FILENAME"
        exit 1
    fi
fi

# 5. Vytvoření spouštěcího skriptu (Launcher)
echo -e "${BLUE}[5/5] Vytvářím spouštěcí skript 'run-qwen3.sh'...${NC}"

# Vypočítáme fyzická jádra
PHYSICAL_CORES=$(grep "^cpu cores" /proc/cpuinfo | uniq | awk '{print $4}')
if [ -z "$PHYSICAL_CORES" ]; then
    PHYSICAL_CORES=$(($(nproc) / 2))
fi

# Vytvoření launcheru
cat <<EOF > run-qwen3.sh
#!/bin/bash
# Spouštěcí skript pro Qwen 3 na llama.cpp

CDir="\$HOME/ai-local/llama.cpp"
Model="\$HOME/ai-local/models/Qwen_Qwen3-14B-Q4_K_M.gguf"

# KONTROLA EXISTENCE MODELU
if [ ! -f "\$Model" ]; then
    echo "CHYBA: Model nebyl nalezen na cestě: \$Model"
    exit 1
fi

echo "============================================"
echo "   Qwen 3 (14B) - llama.cpp launcher"
echo "============================================"
echo ""

# Detekce fyzických jader
PHYSICAL_CORES=\$(grep "^cpu cores" /proc/cpuinfo | uniq | awk '{print \$4}')
if [ -z "\$PHYSICAL_CORES" ]; then
    PHYSICAL_CORES=\$(( \$(nproc) / 2 ))
fi

echo "Spouštím Qwen 3 na \$PHYSICAL_CORES vláknech..."
echo ""

# PARAMETRY:
# -t         : Počet vláken (optimální = fyzická jádra)
# -n -1      : Nekonečná délka generování
# -cnv       : Chat mód (konverzace)
# -fa        : Flash Attention
# --temp 0.7 : Teplota (kreativita)
# --color    : Barevný výstup

\$CDir/build/bin/llama-cli \\
    -m "\$Model" \\
    -t \$PHYSICAL_CORES \\
    -n -1 \\
    -cnv \\
    -p "You are Qwen, a helpful AI assistant created by Alibaba Cloud." \\
    --color \\
    -fa \\
    --temp 0.7 \\
    \$@
EOF

chmod +x run-qwen3.sh

# Vytvoření benchmarkového skriptu
echo -e "${BLUE}[BONUS] Vytvářím benchmark skript 'bench-qwen3.sh'...${NC}"

cat <<EOF > bench-qwen3.sh
#!/bin/bash
# Benchmark skript pro měření rychlosti Qwen 3

CDir="\$HOME/ai-local/llama.cpp"
Model="\$HOME/ai-local/models/Qwen_Qwen3-14B-Q4_K_M.gguf"

echo "============================================"
echo "   Qwen 3 (14B) - Benchmark rychlosti"
echo "============================================"
echo ""

# Zjištění počtu jader
PHYSICAL_CORES=\$(grep "^cpu cores" /proc/cpuinfo | uniq | awk '{print \$4}')
if [ -z "\$PHYSICAL_CORES" ]; then
    PHYSICAL_CORES=\$(( \$(nproc) / 2 ))
fi

echo "Testuji různé počty vláken (optimální je obvykle \$PHYSICAL_CORES)..."
echo ""

# Test s 512 a 1024 tokeny na vstupu, 128 tokenů výstup
\$CDir/build/bin/llama-bench \\
    -m "\$Model" \\
    -p 512,1024 \\
    -n 128 \\
    -t \$((PHYSICAL_CORES-2)),\$PHYSICAL_CORES,\$((PHYSICAL_CORES+2))

echo ""
echo "Benchmark dokončen. Hledejte sloupec 't/s' (tokens per second)."
EOF

chmod +x bench-qwen3.sh

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}HOTOVO! Instalace Qwen 3 dokončena.${NC}"
echo -e ""
echo -e "Model spustíte příkazem:"
echo -e "${BLUE}  $INSTALL_DIR/run-qwen3.sh${NC}"
echo -e ""
echo -e "Změřit rychlost můžete příkazem:"
echo -e "${BLUE}  $INSTALL_DIR/bench-qwen3.sh${NC}"
echo -e "${GREEN}==============================================${NC}"
