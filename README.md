# script_BpG


# Pipeline de Análise IBBC (Paired-End & Single-End)

Este pipeline automatiza o processamento de dados de sequenciação. Ele organiza tudo em pastas, faz o controlo de qualidade, limpa as sequências e tenta fazer a montagem de organelos.

## 1. Instalação e Preparação (Só precisas de fazer isto uma vez)

Antes de correr o script, tens de ter o ambiente **Conda** pronto. Se ainda não tens nada instalado no computador/servidor, segue estes passos pela ordem:

### A. Instalar o Miniconda (se não tiveres)
Abre o terminal e corre:

wget [https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh](https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh)
bash Miniconda3-latest-Linux-x86_64.sh

Aceita a licença e diz "yes" quando ele perguntar se queres inicializar o conda. Importante: Fecha o terminal e abre um novo para as alterações fazerem efeito.
B. Configurar os canais de Bioinformática

Copia e cola isto para configurar onde vamos buscar os programas:
Bash

conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
conda config --set channel_priority strict

C. Criar o ambiente e instalar as ferramentas

Vamos criar um ambiente chamado bioinfo com tudo o que precisamos:
Bash

conda create -n bioinfo fastqc fastp getorganelles -y

D. Baixar a base de dados do GetOrganelles

Este passo é crucial, senão a montagem falha. Pode demorar um pouco:
Bash

conda activate bioinfo
get_organelles_from_reads.py --download-references embplant_pt,embplant_mt

2. Como usar o Script

Sempre que quiseres analisar dados, segue estes passos:

    Ativa o ambiente:
    Bash

conda activate bioinfo

Entra na pasta dos scripts e executa:
Bash

    chmod +x pipeline_ibbc.sh   # (Só precisas dar permissão na 1ª vez)
    ./pipeline_ibbc.sh

    Segue as instruções no ecrã:

        O script vai perguntar se é um Projeto Novo (cria pastas) ou para Retomar (usa pastas existentes).

        Se for novo, ele pede o caminho dos teus ficheiros FASTQ brutos e copia-os.

        Podes escolher quais passos queres correr (FastQC, Fastp, etc).

3. O que o Pipeline faz?

    Organização: Cria uma pasta Project_ibbc_TeuNome com subpastas para data, results, logs e scripts.

    Detecção: Percebe automaticamente se tens ficheiros Paired-End (R1+R2) ou ficheiros sozinhos e trata-os de forma diferente.

    Resume: Se a análise parar a meio, podes correr de novo e ele não repete o que já está feito.

    Logs: Tudo o que acontece fica gravado na pasta logs.

4. Resultados

No final, vais encontrar tudo na pasta results:

    fastqc_raw/: Relatórios de qualidade dos dados originais.

    fastp_clean/: Os teus ficheiros FASTQ limpos e prontos a usar.

    fastqc_clean/: Relatórios de qualidade depois da limpeza (para confirmares que melhorou).

    getorganelles/: O resultado da montagem (os genomas montados).

No fim, o script pergunta se queres criar um ficheiro .tar.gz com tudo pronto para enviar ou guardar.
