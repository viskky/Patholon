[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A523.04-brightgreen.svg)](https://www.nextflow.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey)
[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg?style=flat)](http://bioconda.github.io/recipes/python-nextflow/README.html)

# Patholon-nf

> A custom pipeline for microbiome analysis of Oxford Nanopore sequencing data — detecting antimicrobial resistance (AMR) genes,
> virulence factor, plasmids, protein domains, and microbial taxonomic diversity.

---

## Table of Contents

- [Overview](#overview)

- [Requirements](#requirements)

- [Installation](#installation)

- [Database Setup](#database-setup)

- [Usage](#usage)

- [Output Structure](#output-structure)

- [Profiles](#profiles)

- [Troubleshooting](#troubleshooting)

---

## Overview

```
FASTQ Input
    │
    ├─→ FastQC/NanoPlot (raw)     Quality assessment of raw reads
    │
    ├─→ Porechop                  Adapter & barcode trimming
    │
    ├─→ FastQC/NanoPlot (trimmed) Quality assessment of trimmed reads
    │
    ├─→ Flye / MEGAHIT            De novo metagenome assembly
    │
    ├─→ QUAST                     Assembly quality metrics
    │
    ├─→ Prokka                    Gene annotation
    │       │
    │       ├─→ ABRicate          AMR gene/Plasmid/Virulence Factor detection
    │       │
    │       └─→ HMMsearch         Phage-like protein detection
    │    	   │
    │          └─→ BLASTP         Protein Homology against a reference database
    │
    ├─→ Kraken2                   Taxonomic classification
    │
    ├─→ KronaTools                Interactive diversity charts from Kraken2 report
    │
    └─→ MultiQC                   Unified QC and Taxonomy summary report
```

---

## Requirements

### System

- Linux (Ubuntu 20.04+ recommended)

- ≥ 16 GB RAM (≥ 64 GB for Kraken2 standard database)

- ≥ 100 GB disk space (assembly + databases)

- Java 17 or higher

### Software

- [Nextflow](https://www.nextflow.io/) ≥ 25.10

- [Conda](https://docs.conda.io/) (recommended) or [Mamba](https://mamba.readthedocs.io/) 

---

## Installation

### 1\. Clone the repository

```bash
git clone https://github.com/viskky/patholon.git
cd patholon
```

### 2\. Run the installer

```bash
bash install.sh
```

This will:

- Check/install Nextflow

- Create the `Patholon-nf` conda environment

- Make all helper scripts executable

- Update the KronaTools taxonomy database

- Check ABRicate database availability

### 3\. Activate the environment

```bash
conda activate Patholon-nf
```

---

## Database Setup

### Kraken2 Database

A Kraken2 database is required for taxonomic classification.

```bash
mkdir -p databases/kraken2

# Standard 8 GB database (recommended for most users)
wget https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20231009.tar.gz
tar -xzf k2_standard_08gb_20231009.tar.gz -C databases/kraken2/
rm -fr k2_standard_08gb_20231009.tar.gz
```

> [Full database index](https://benlangmead.github.io/aws-indexes/k2)

### Phage HMM Database

Choose your phage protein HMM databases:  https://www.ebi.ac.uk/interpro/entry/pfam/#table

```bash
mkdir -p databases/hmm

Download your HMM files to this directory path
```

### BLASTP Databases

```bash
mkdir -p databases/blast

# Swiss-Prot (for smaller space, ~250 MB):
wget -P databases/blast https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz \
&& gunzip databases/blast/uniprot_sprot.fasta.gz

```

### ABRicate Databases

ABRicate databases are bundled with the tool and auto-downloaded on first use:

```bash
# List available databases
abricate --list

# Update all databases
abricate --setupdb

# Available databases:
#   ncbi           NCBI AMRFinderPlus
#   card           CARD (Comprehensive Antibiotic Resistance Database)
#   resfinder      ResFinder
#   vfdb           Virulence Factor Database
#   plasmidfinder  PlasmidFinder
#   argannot       ARG-ANNOT
#   ecoh           E. coli O antigen
```

---

## Usage

### Single FASTQ file using --qctool nanoplot, --abricate_db ncbi & --assembler flye

```bash
nextflow run Patholon.nf \
    --input reads.fastq.gz \
    --assembler flye \
    --kraken2_db databases/kraken2 \
    --abricate_db ncbi \
    --qc_tool nanoplot \
    --blastp_db databases/blast/* \
    --hmm_db path_to_HMMfile_directory \
    --outdir results/
```

### Multiple samples (glob) using --qctool fastqc, --abricate_db vfdb & --assembler megahit

```bash
nextflow run Patholon.nf \
    --input 'data/*.fastq.gz' \
    --assembler megahit \
    --kraken2_db databases/kraken2 \
    --qc_tool fastqc \
    --abricate_db vfdb \
    --hmm_db path_to_HMMfile_directory \
    --outdir results/
```

### Multiple samples (datasheet)

```bash
# Edit the template
nano assets/datasheet.csv

# Run
nextflow run Patholon.nf \
    --input assets/datasheet.csv \
    --assembler megahit \
    --qc_tool fastqc \
    --kraken2_db databases/kraken2 \
    --hmm_db path_to_HMMfile_directory \
    --outdir results/
```

Datasheet format (`CSV`):

```
sample,fastq
sample_01,/path/to/sample_01.fastq.gz
sample_02,/path/to/sample_02.fastq.gz
```

### All parameters

```
Parameter          Default     Description
--input            required    FASTQ file(s) or datasheet CSV
--outdir           results     Output directory
--qc_tool	   fastqc      Quality Control: 'fastqc' or 'nanoplot'
--assembler        flye        Assembly tool: 'flye' or 'megahit'
--kraken2_db       required    Path to Kraken2 database directory
--hmm_db           required    Path to phage HMM profile (.hmm)
--blastp_db	not mandated   Path to BLASTP reference database
--abricate_db      ncbi        ABRicate database name
--genome_size      5m          Estimated genome size (for Flye)
--min_read_len     200         Min read length after trimming (bp)
--min_contig_len   500         Min contig length for annotation (bp)
--threads          8           CPU threads per process
```

---

## Output Structure

```
results/
├── 01_qc/
│   ├── raw/              		   FastQC HTML + ZIP / NanoPlot (raw reads)
│   └── trimmed/          		   FastQC HTML + ZIP / NanoPlot (trimmed reads)
│
├── 02_porechop/          		   Trimming logs
│
├── 03_assembly/
│   └── flye/MEGAHIT      		   Assembly FASTA (contigs), graph, info
│
├── 04_quast/            		   QUAST HTML + TSV reports
│
├── 05_prokka/        		       GFF, FAA, GBK, FFN annotation files
│
├── 06_abricate/
│   ├── <sample>/          		   Per-sample AMR TSV
│   └── <sample>/          		   Per-sample PLASMID TSV
│
├── 07_hmmsearch/
│   └── <sample>/          		   Phage domain hit tblout + filtered TSV
│
├── 08_blastp/
│   ├── <sample>/         		   BLASTP + summary TSV
│
├── 09_kraken2/
│   └── <sample>/          		   Kraken2 report
│
├── 10_krona/
│   └── <sample>_krona.html        Interactive and visualised chart from Kraken2 report
│
├── 11_multiqc/
│   ├── multiqc_report.html        Unified QC and Taxonomy report
│   └── multiqc_data/              Raw data
│
└── pipeline_info/
    ├── timeline_*.html
    ├── report_*.html
    ├── trace_*.txt
    └── dag_*.html
```


## Profiles

```bash
# Local execution (default)
nextflow run Patholon.nf -profile standard [options]

# Conda environment
nextflow run Patholon.nf -profile conda [options]

```

---

## Troubleshooting

### Resume a failed run after fixing bug

```bash
nextflow run Patholon.nf [options] -resume
```

---

## Citation

If you use this pipeline for analysis, please cite as:

Betiku V.O xxxx

A list of references for the tools used by the pipeline can be found in the [CITATIONS.md](https://github.com/viskky/Patholon/blob/main/docs/CITATIONS.md) file

---

## License

This pipeline uses code and infrastructure developed and maintained under the MIT License — see [LICENSE](https://github.com/viskky/patholon/blob/main/LICENSE) for details.
