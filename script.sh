#!/bin/bash

# ==============================================================================
# NOME: script.sh
# DESCRIÇÃO: Pipeline  (FastQC/MultiQC -> Fastp -> GetOrganelle)
# ==============================================================================

# --- VERIFICAÇÃO INICIAL ---
if [[ -z "$CONDA_DEFAULT_ENV" ]]; then
    echo "[ERRO] Nenhum ambiente Conda detetado."
    exit 1
fi

# --- FUNÇÕES ---

funcao_fastqc() {
    local dir_in=$1
    local dir_out=$2
    local threads=$3
    local label=$4
    echo "[AÇÃO] FastQC a decorrer na pasta: $(basename "$dir_in") ($label)"
    mkdir -p "$dir_out"
    # comando fastqc
    fastqc --quiet -t "$threads" "$dir_in"/*.fastq* "$dir_in"/*.fq* -o "$dir_out" > /dev/null 2>&1
}

funcao_multiqc() {
    local dir_base=$1
    echo "[AÇÃO] A executar MultiQC..."
    # O MultiQC vê a pasta results e substitui o report anterior se existir
    multiqc "$dir_base/results" -o "$dir_base/results/multiqc_report" --force --quiet > /dev/null 2>&1 
    echo "[INFO] Relatório gerado: $dir_base/results/multiqc_report/multiqc_report.html" #diz onde ficou 
}

funcao_fastp() {
    # variaveis
    local r1=$1
    local r2=$2
    local out_r1=$3
    local out_r2=$4
    local out_s=$5
    local html=$6
    local json=$7
    local args_user=$8
    local threads=$9

    # Comando base; fastp com r1 e out_read1 html json threads e args (argumentos) adicionais
    local cmd="fastp -i $r1 -o $out_r1 -h $html -j $json -w $threads $args_user"

    if [[ -n "$r2" ]]; then # se a r2 (read2 não for nula então:)
        # Paired-End; adiciona novos argumentos e deteta adapters
        $cmd -I "$r2" -O "$out_r2" --detect_adapter_for_pe
    else
        # Single-End; comando base
        $cmd
    fi
}

funcao_getorganelle() {
    local r1=$1; local r2=$2; local dir_out=$3; local db=$4; local threads=$5
    
    # cria pasta de saída
    mkdir -p "$dir_out" 
    #salta a criação de pasta, caso já exista ou não esteja vazia
    if [[ -d "$dir_out" && "$(ls -A $dir_out 2>/dev/null)" ]]; then
        echo "Pasta GetOrganelle já existe. A saltar..."; return
    fi
    
    #comando base
    local cmd="get_organelle_from_reads.py -o $dir_out -F $db -w 115 -R 10 -t $threads --overwrite"
    #comando com argumentos para paired end; ou else com apenas um argumento
    if [[ -n "$r2" ]]; then $cmd -1 "$r1" -2 "$r2"; else echo "[AVISO] Modo Unpaired..."; $cmd -u "$r1"; fi
}

# --- SCRIPT PRINCIPAL ---

clear #começa com o terminal limpo
echo "======================================================="
echo "         PIPELINE IBBC - ANÁLISE GENÓMICA              "
echo "======================================================="

# MENU
echo ""
echo "1) Novo Projeto"
echo "2) Retomar Existente"
read -p "Opção: " OPCAO

# MENU - criar novo projeto
if [[ "$OPCAO" == "1" ]]; then

    read -p "Nome do Utilizador: " USER
    DIR_PROJ="Project_ibbc_${USER}"
    if [[ ! -d "$DIR_PROJ" ]]; then #se nao (!) diretorio (-d) caminho ($dir_proj) logo:
        # criar pastas dentro do projeto
        mkdir -p "$DIR_PROJ"/{data,scripts,results,logs}
        mkdir -p "$DIR_PROJ"/results/{fastqc_raw,fastqc_clean,fastp_clean,getorganelle,multiqc_report}
        # guardar tbm o script atual
        cp "$0" "$DIR_PROJ/scripts/"
    fi
# MENU - retomar projeto existente    
else
    while true; do # loop para perguntar novamente caso dê erro
        read -p "Caminho do Projeto: " DIR_PROJ
        DIR_PROJ=$(echo "$DIR_PROJ" | tr -d "'") # remove aspas quando se copiar o diretorio (para colar localizacao)
        DIR_PROJ="${DIR_PROJ/#\~/$HOME}" # no dir substitui (#) "\~" por (/) $home
        # se existir a pasta ent continua o script, senão erro
        if [[ -d "$DIR_PROJ" ]]; then break; else echo "[ERRO] Pasta não encontrada."; fi
    done
fi

# Logs e 
# Ativa o sistema de logs Grava  tuddo de mensagens e erros no log
# com data e horas enquanto tambem mostra o output no ecrã. (tee -a)
exec > >(tee -a "${DIR_PROJ}/logs/log_$(date +%Y%m%d_%H%M).txt") 2>&1
DIR_DATA="${DIR_PROJ}/data"

# Verifica se a pasta data do projeto está vazia, se estiver vai pedir os fastq originais
if [ -z "$(ls -A $DIR_DATA 2>/dev/null)" ]; then
    read -p "Caminho dos FASTQ originais: " ORIGEM
    ORIGEM=$(echo "$ORIGEM" | tr -d "'") # tira aspas do caminho
    rsync -avP "${ORIGEM/#\~/$HOME}/" "$DIR_DATA/" #substitui pelo caminho completo
fi

# Classificação de pares ou single por listas, se tiver 2 no nome junta ao 1 e põe na lista
PARES_R1=(); SINGLETONS=()
for f in $(ls "$DIR_DATA"/*.fastq* "$DIR_DATA"/*.fq* 2>/dev/null); do
    if [[ "$f" == *"_R2"* || "$f" == *"_2."* || "$f" == *"_2_"* ]]; then continue; fi
    if [[ "$f" == *"_R1"* ]]; then par="${f/_R1/_R2}"; elif [[ "$f" == *"_1."* ]]; then par="${f/_1./_2.}"; else par=""; fi
    if [[ -n "$par" && -f "$par" ]]; then PARES_R1+=("$f"); else SINGLETONS+=("$f"); fi
done

# --- FASE 1: DIAGNÓSTICO INICIAL ---
echo ""
echo "--- FASE 1: DIAGNÓSTICO INICIAL (RAW DATA) ---"

if [[ -d "${DIR_PROJ}/results/fastqc_raw" && "$(ls -A "${DIR_PROJ}/results/fastqc_raw" 2>/dev/null)" ]]; then
    echo "[INFO] Resultados do FastQC Raw já existem. A saltar esta etapa."
else
    #"raw data" serve para echos, não pertence ao comando mesmo; diferentes variaveis temporarias (4 é as threats da funcao)
    funcao_fastqc "$DIR_DATA" "${DIR_PROJ}/results/fastqc_raw" 4 "Raw Data" 
    #multiqc como da funcao no diretorio do projeto
    funcao_multiqc "${DIR_PROJ}"
fi

echo ""
echo ">>> Relatório MultiQC: ${DIR_PROJ}/results/multiqc_report/"
echo ">>> Abrir o ficheiro HTML para verificar a qualidade."

# --- FASE 2: LOOP DE LIMPEZA E OTIMIZAÇÃO ---
while true; do
    echo ""
    echo "--- FASE 2: FASTP ---"
    read -p "Deseja realizar a limpeza (Fastp) agora? (s/n): " RUN_FASTP

    #se for não saltar
    if [[ "$RUN_FASTP" != "s" ]]; then
        echo "A saltar o Fastp..."
        break
    fi

    echo ""
    echo "DEFINIÇÃO DE PARÂMETROS (Enter para aceitar outro nº para alterar):"

    ##### argumentos do fastp #####

    # 1. Qualidade
    read -p "1. Qualidade Mínima Phred (-q) [15]: " P_Q
    P_Q=${P_Q:-15} # ":" => se; "-" => nula; substituir por 15

    # 2. Percentagem
    read -p "2. % Bases Não Qualificadas permitidas (-u) [40]: " P_U
    P_U=${P_U:-40}

    # 3. Tamanho Mínimo
    read -p "3. Tamanho Mínimo da Read (-l) [15]: " P_L
    P_L=${P_L:-15}

    # 4. TRIMMING HARD (Frente) - Agora pede numero, nao s/n
    read -p "4. Quantas bases cortar na FRENTE/5' (-f/--trim_front1) [0]: " P_TRIM_F
    P_TRIM_F=${P_TRIM_F:-0}

    # 5. TRIMMING HARD (Cauda) - Agora pede numero, nao s/n
    read -p "5. Quantas bases cortar na CAUDA/3' (-t/--trim_tail1) [0]: " P_TRIM_T
    P_TRIM_T=${P_TRIM_T:-0}

    # 6. POLY G (O teu pedido especifico)
    read -p "6. Ativar deteção/corte de caudas PolyG? (--trim_poly_g) [s/n] (padrao: n): " P_POLYG
    
    # Se ativar PolyG, define tamanho
    POLY_G_CMD=""
    if [[ "$P_POLYG" == "s" ]]; then
        read -p "   > Tamanho mínimo para detetar PolyG (--poly_g_min_len) [10]: " P_POLYG_LEN
        P_POLYG_LEN=${P_POLYG_LEN:-10}
        POLY_G_CMD="--trim_poly_g --poly_g_min_len $P_POLYG_LEN"
    else
        # Se nao ativar, garantimos que esta desligado (para Novaseq que liga automatico)
        POLY_G_CMD="--disable_trim_poly_g"
    fi

    echo "Outros parâmetros (ex: --dedup). Deixa vazio se não quiseres:"
    read P_EXTRA

    # Construção da string de argumentos
    # Nota: O fastp ignora -f 0 ou -t 0, por isso podemos passar direto
    ARGS_FASTP="-q $P_Q -u $P_U -l $P_L -f $P_TRIM_F -t $P_TRIM_T $POLY_G_CMD $P_EXTRA"

    echo ""
    echo "[AÇÃO] A correr Fastp com: $ARGS_FASTP"
    
    # --- Execução Fastp (Pares) ---
    for r1 in "${PARES_R1[@]}"; do # para cada par da lista
    # se r1 for "_r1" ent substituir o caminho *_R1 por *R2, ou _1 por _2
        if [[ "$r1" == *"_R1"* ]]; then r2="${r1/_R1/_R2}"; else r2="${r1/_1./_2.}"; fi
        # base serve para ficar so com o nome base ex em: "girafa_r1.fastq" => "girafa"
        base=$(basename "$r1" | sed 's/_R1.*//' | sed 's/_1\..*//')
        funcao_fastp "$r1" "$r2" \
            "${DIR_PROJ}/results/fastp_clean/${base}_clean_1.fq.gz" \
            "${DIR_PROJ}/results/fastp_clean/${base}_clean_2.fq.gz" \
            "" \
            "${DIR_PROJ}/results/fastp_clean/${base}.html" \
            "${DIR_PROJ}/results/fastp_clean/${base}.json" \
            "$ARGS_FASTP" 8
    done

    # --- Execução Fastp (Singles) ---
    for s in "${SINGLETONS[@]}"; do
        #nome base do ficheiro 
        base=$(basename "$s" | sed 's/\.fastq.*//' | sed 's/\.fq.*//')
        funcao_fastp "$s" "" \
            "${DIR_PROJ}/results/fastp_clean/${base}_clean.fq.gz" \
            "" "" \
            "${DIR_PROJ}/results/fastp_clean/${base}.html" \
            "${DIR_PROJ}/results/fastp_clean/${base}.json" \
            "$ARGS_FASTP" 8
    done # "" "" \ serve para saltar argumentos definidos na funcao do fastp

    # Corre fastQC e multiqc nos dados limpos automaticamente
    echo ""
    echo "[AÇÃO] A verificar novamente com FastQC..."
    funcao_fastqc "${DIR_PROJ}/results/fastp_clean" "${DIR_PROJ}/results/fastqc_clean" 4 "Clean Data"
    funcao_multiqc "${DIR_PROJ}"

    echo ""
    echo "--------------------------------------------------------"
    echo " CONCLUÍDO."
    echo " Verificar o NOVO relatório MultiQC em: results/multiqc_report/"
    echo "--------------------------------------------------------"
    read -p "Está satisfeito com o Fastp? (s = avançar / n = repetir com outros parâmetros): " SATISFEITO
    
    if [[ "$SATISFEITO" == "s" ]]; then
        break
    else
        echo "[INFO] A reiniciar o Fastp. Os ficheiros anteriores serão substituídos."
    fi
done

# --- FASE 3: MONTAGEM ---
echo ""
echo "--- FASE 3: GetOrganelle ---"
read -p "Executar GetOrganelle? (s/n): " RUN
if [[ "$RUN" == "s" ]]; then
    read -p "  Base de dados (ex: embplant_pt,embplant_mt): " DB
    CLEAN_PAIRS=($(ls "${DIR_PROJ}/results/fastp_clean/"*_clean_1.fq.gz 2>/dev/null))
    
    for r1 in "${CLEAN_PAIRS[@]}"; do
        r2="${r1/_1.fq.gz/_2.fq.gz}"
        amostra=$(basename "$r1" | sed 's/_clean_1.fq.gz//')
        funcao_getorganelle "$r1" "$r2" "${DIR_PROJ}/results/getorganelle/${amostra}" "${DB:-embplant_pt,embplant_mt}" 4
    done
else
    echo "A saltar o GetOrganelle..."
fi

# FIM
echo ""
echo "--- FIM DO PIPELINE ---"

read -p "Criar tar.gz final? (s/n): " TAR

if [[ "$TAR" == "s" ]]; then
    tar -czf "${DIR_PROJ}_resultados.tar.gz" --exclude="$DIR_PROJ/data" "$DIR_PROJ"
    echo "Ficheiro criado: ${DIR_PROJ}_resultados.tar.gz"
    echo "Script Terminado..."
    echo "A fechar em 2 segundos..."
    sleep 2
else
    echo "A saltar etapa e a terminar o script..."
    echo "A fechar em 2 segundos..."
    sleep 2
fi