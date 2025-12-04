# Pipeline de Análise Genómica (IBBC)

Este repositório contém um pipeline automatizado em Bash para o processamento de dados de sequenciação (*Illumina Paired-End* e *Single-End*). O script gere a estrutura de diretórios, realiza o controlo de qualidade, limpeza de leituras e montagem de organelos de forma interativa e reprodutível.

## Funcionalidades

  * **Estruturação Automática:** Criação de diretórios padronizados (`data`, `results`, `logs`, `scripts`).
  * **Controlo de Qualidade (QC):** Análise inicial e final com **FastQC**.
  * **Limpeza e Trimming:** Processamento de leituras com **Fastp** (deteção automática de adaptadores).
  * **Montagem de Organelos:** Montagem direcionada de plastomas e mitogenomas usando **GetOrganelle**.
  * **Gestão de Sessão:** Sistema de *logs* detalhados e capacidade de retomar análises interrompidas ("Resume").

## Pré-requisitos

Para executar este pipeline, o sistema deve ter um ambiente **Conda** configurado e ativo.

O script pressupõe que as seguintes ferramentas estão instaladas e acessíveis no PATH:

  * `fastqc`
  * `fastp`
  * `getorganelle`

Além disso, é necessário que as **bases de dados de referência** do GetOrganelle já tenham sido descarregadas (ex: `embplant_pt,embplant_mt`).

## Instalação

Basta clonar este repositório ou copiar o ficheiro `pipeline_ibbc.sh` para o servidor e atribuir permissões de execução:

```bash
chmod +x pipeline_ibbc.sh
```

## Utilização

Recomenda-se vivamente a execução dentro de uma sessão `screen` para evitar interrupções em processos longos (como a montagem de genomas).

### 1\. Preparação

Iniciar a sessão e ativar o ambiente:

```bash
screen -S analise_ibbc
conda activate bioinfo
```

*(Substitua `bioinfo` pelo nome do seu ambiente conda, se for diferente).*

### 2\. Execução

Correr o script na pasta onde se encontra:

```bash
./pipeline_ibbc.sh
```

### 3\. Fluxo Interativo

O script guiará o utilizador através das seguintes etapas:

1.  **Configuração do Projeto:**
      * **Novo Projeto:** O utilizador indica o nome e o caminho dos ficheiros FASTQ brutos. O script cria a estrutura e importa os dados.
      * **Retomar Existente:** O utilizador indica o caminho de um projeto já iniciado. O script deteta o progresso e permite continuar sem repetir amostras já processadas.
2.  **Seleção de Módulos:**
    É possível escolher correr ou saltar cada etapa individualmente:
      * FastQC (Dados Brutos)
      * Fastp (Limpeza)
      * FastQC (Dados Limpos)
      * GetOrganelle (Montagem)

## Estrutura de Resultados

Todos os ficheiros gerados são organizados na pasta `results` dentro do diretório do projeto:

  * `results/fastqc_raw/`: Relatórios HTML de qualidade antes do processamento.
  * `results/fastp_clean/`: Ficheiros FASTQ processados e relatórios de filtragem (JSON/HTML).
  * `results/fastqc_clean/`: Relatórios HTML de validação após a limpeza.
  * `results/getorganelle/`: Resultados da montagem (Ficheiros FASTA, GFA e logs específicos).

## Logs e Exportação

  * **Logs:** Todo o progresso é gravado na pasta `logs/` com data e hora de execução.
  * **Exportação:** No final, o script oferece a opção de gerar um arquivo `.tar.gz` contendo todos os resultados, scripts e logs (excluindo os dados brutos), pronto para transferência.
