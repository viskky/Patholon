#!/usr/bin/env nextflow

/*
========================================================================================
             PATHOLON-NF PIPELINE
========================================================================================

    Detects:
      - Antimicrobial Resistance (AMR) genes / Virulence Factor
      - Plasmid replicons
      - Protein domain and family                     
      - Microbial taxonomic diversity                       

    Steps:
      1. Quality Control          → FastQC (default) OR NanoPlot
      2. Adapter Trimming         → Porechop
      3. Assembly                 → Flye (default) or MEGAHIT
      4. Assembly QC              → QUAST
      5. Gene Annotation          → Prokka
      6. AMR Detection            → ABRicate
      7. Phage Protein Detection  → HMMsearch
      8.  Protein Homology Search → BLASTP 
      9. Taxonomic Classification → Kraken2
      10. Diversity Visualization → KronaTools

    Contact : victor.obetiku@gmail.com
========================================================================================
*/

nextflow.enable.dsl = 2

//PARAMETER DEFAULTS 

params.input          = null                // Path to input FASTQ(s) or datasheet CSV
params.outdir         = "results"           // Output directory
params.qc_tool        = "fastqc"
params.assembler      = "flye"             // 'flye' or 'megahit'
params.kraken2_db     = "databases/kraken2" // Path to Kraken2 database
params.hmm_db         = null               // Path to phage HMM profile database
params.blastp_db      = "databases/blast/*.fasta" // Path to BLASTP database
params.abricate_db    = "ncbi"
params.genome_size    = "5m"              // Estimated genome size for Flye
params.min_read_len   = 200               // Minimum read length after trimming
params.min_contig_len = 200              // Minimum contig length for annotation
params.threads        = 8                 // Default threads per process
params.help           = false

// HELP MESSAGE 

def helpMessage() {
    log.info """
    ╔══════════════════════════════════════════════════════════════════╗
    ║                PATHOLON-NF PIPELINE  v1.0.0                      ║
    ╚══════════════════════════════════════════════════════════════════╝

    Usage:
        nextflow run Patholon.nf [options]

    Required:
        --input          Path to FASTQ file(s) or datasheet CSV
                         Single file  : --input reads.fastq.gz
                         Multiple     : --input 'path/to/*.fastq.gz'
                         Datasheet  : --input datasheet.csv
        --hmm_db         Path to custom phage HMM profile (.hmm file)

    Optional:
        --outdir         Output directory [default: results]
        --assembler      Assembly tool: 'flye' or 'megahit' [default: flye]
        --qc_tool        QC tool: 'fastqc' or 'nanoplot' [default: fastqc]
        --blastp_db      Path to BLASTP protein database (BLAST db) [default: uniprot(swissprot)]
                         If omitted, BLASTP step is skipped
        --abricate_db    ABRicate database [default: ncbi]
                         Options: ncbi, card, resfinder, vfdb, argannot
        --kraken2_db     Path to Kraken2 database directory [default: standard 8GB kraken database]
        --genome_size    Estimated genome size for Flye [default: 5m]
        --min_read_len   Minimum read length after trimming [default: 200]
        --min_contig_len Minimum contig length for annotation [default: 500]
        --threads        Threads per process [default: 8]
        --help           Show this help message

    Examples:
        # Single file, FASTQC, Flye assembler, with BLASTP
        nextflow run Patholon.nf \\
	    --qc_tool fastqc \\
            --input sample.fastq.gz \\
            --kraken2_db databases/kraken2 \\
            --hmm_db path_to_HMM_file.hmm \\
	        --blastp_db databases/blast/*.fasta \\
            --outdir results/

        # Multiple samples via datasheet, NanoPlot QC, MEGAHIT assembler
        nextflow run Patholon.nf \\
            --input datasheet.csv \\
            --qc_tool nanoplot \\
            --assembler megahit \\
            --kraken2_db databases/kraken2 \\
            --hmm_db path_to_HMM_file.hmm  \\
	        --blastp_db databases/blast/*.fasta \\
			--outdir results/

    Datasheet format (CSV):
        sample,fastq
        sample1,/path/to/sample1.fastq.gz
        sample2,/path/to/sample2.fastq.gz
    """.stripIndent()
}

if (params.help) {
    helpMessage()
    exit 0
}

// INPUT VALIDATION 

if (!params.input) {
    log.error "ERROR: --input is required. Use --help for usage."
    exit 1
}
if (!params.kraken2_db) {
    log.error "ERROR: --kraken2_db is required. Use --help for usage."
    exit 1
}
if (!params.hmm_db) {
    log.error "ERROR: --hmm_db is required. Use --help for usage."
    exit 1
}

if (!['fastqc', 'nanoplot'].contains(params.qc_tool)) {
    log.error "ERROR: --qc_tool must be 'fastqc' or 'nanoplot'. Got: ${params.qc_tool}"
    exit 1
}

if (!['flye', 'megahit'].contains(params.assembler)) {
    log.error "ERROR: --assembler must be 'flye' or 'megahit'. Got: ${params.assembler}"
    exit 1
}

//  LOG PIPELINE INFO 

log.info """
╔══════════════════════════════════════════════════════════════════╗
║              PATHOLON-NF PIPELINE  v1.0.0                        ║
╚══════════════════════════════════════════════════════════════════╝
  input          : ${params.input}
  outdir         : ${params.outdir}
  qc_tool        : ${params.qc_tool}
  assembler      : ${params.assembler}
  kraken2_db     : ${params.kraken2_db}
  hmm_db         : ${params.hmm_db}
  blastp_db      : ${params.blastp_db ?: 'not provided (step skipped)'}
  abricate_db    : ${params.abricate_db}
  genome_size    : ${params.genome_size}
  min_read_len   : ${params.min_read_len}
  min_contig_len : ${params.min_contig_len}
  threads        : ${params.threads}
"""

//  INCLUDE MODULES 

include { FASTQC as FASTQC_RAW} from './modules/fastqc'
include { NANOPLOT as NANOPLOT_RAW} from './modules/nanoplot'
include { PORECHOP       } from './modules/porechop'
include { FASTQC as FASTQC_TRIM} from './modules/fastqc'
include { NANOPLOT as NANOPLOT_TRIM} from './modules/nanoplot'
include { FLYE           } from './modules/flye'
include { MEGAHIT        } from './modules/megahit'
include { QUAST          } from './modules/quast'
include { PROKKA         } from './modules/prokka'
include { ABRICATE_AMR    } from './modules/abricate'
include { ABRICATE_PLASMID } from './modules/abricate'
include { HMMSEARCH      } from './modules/hmmsearch'
include { BLASTP           } from './modules/blastp'
include { KRAKEN2        } from './modules/kraken2'
include { KRONATOOLS      } from './modules/kronatools'
include { MULTIQC        } from './modules/multiqc'

//  INPUT CHANNEL 

def createInputChannel(input_path) {
    def inputFile = file(input_path)

    // Datasheet CSV
    if (inputFile.name.endsWith('.csv')) {
        return Channel
            .fromPath(input_path)
            .splitCsv(header: true)
            .map { row ->
                def sample = row.sample
                def fastq  = file(row.fastq)
                if (!fastq.exists()) error "FASTQ not found: ${fastq}"
                return tuple(sample, fastq)
            }
    }

    // Glob or single FASTQ
    return Channel
        .fromPath(input_path)
        .map { f ->
            def sample = f.baseName.replaceAll(/\.(fastq|fq)(\.gz)?$/, '')
            return tuple(sample, f)
        }
}

//  WORKFLOW 

workflow {

    // Create input channel
    reads_ch = createInputChannel(params.input)

    // Step 1: Quality Control (raw reads) 
   
    if (params.qc_tool == "fastqc") {
        FASTQC_RAW(reads_ch, "raw")
        qc_zip_raw = FASTQC_RAW.out.zip   // used later by MultiQC
    } else {
        NANOPLOT_RAW(reads_ch, "raw")     // 
        qc_zip_raw = NANOPLOT_RAW.out.stats  // NanoPlot has no .zip; MultiQC collects its dir
    }

    //  Step 2: Adapter & Barcode Trimming 
    PORECHOP(reads_ch)

    // Filter by minimum read length using bin/filter_reads.py
    filtered_ch = PORECHOP.out.trimmed
        .map { sample, fastq -> tuple(sample, fastq) }

    //  Step 3: Quality Control (trimmed reads) 
    
    if (params.qc_tool == "fastqc") {
        FASTQC_TRIM(filtered_ch, "trimmed")
        qc_zip_trimmed = FASTQC_TRIM.out.zip
    } else {
        NANOPLOT_TRIM(filtered_ch, "trimmed")  
        qc_zip_trimmed = NANOPLOT_TRIM.out.stats
    }

    //  Step 4: Assembly 
    if (params.assembler == "flye") {
        FLYE(filtered_ch)
        assembly_ch = FLYE.out.assembly
    } else if (params.assembler == "megahit") {
        MEGAHIT(filtered_ch)
        assembly_ch = MEGAHIT.out.assembly
    } else {
        error "Unknown assembler: ${params.assembler}. Choose 'flye' or 'megahit'."
    }

    //  Step 5: Assembly Quality Control 
    QUAST(assembly_ch)

    //  Step 6: Gene Annotation 
    PROKKA(assembly_ch)

    // ── Step 7: AMR Gene Detection 
    ABRICATE_AMR(assembly_ch)
    ABRICATE_PLASMID(assembly_ch)

    //  Step 8: Protein Family Detection 
    HMMSEARCH(
        PROKKA.out.faa,
        file(params.hmm_db)
    )

    //  Step 9: BLASTP  top 5 hits per protein homologues 
    // Only runs when --blastp_db is provided
    if (params.blastp_db) {
        BLASTP(PROKKA.out.faa, file(params.blastp_db))
    } else {
        log.warn "BLASTP skipped: --blastp_db not provided."
    }

    // Step 9: Taxonomic Classification
    KRAKEN2(
        filtered_ch,
        file(params.kraken2_db)
    )

    // Step 10: Diversity Visualization 
    KRONATOOLS(KRAKEN2.out.report)
    
    //  Step 11: MultiQC Summary Report 

    multiqc_input = qc_zip_raw
		.mix(qc_zip_trimmed)
		.mix(QUAST.out.results)
		.mix(PROKKA.out.stats)
	        .mix(KRAKEN2.out.report)
		.map{ it[1] }
		.collect()

    MULTIQC(multiqc_input)
}

//  COMPLETION HANDLER 

workflow.onComplete {
    log.info """
    ╔══════════════════════════════════════════════════════════════════╗
    ║                  PIPELINE COMPLETED                              ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║  Status   : ${workflow.success ? 'SUCCESS ✓' : 'FAILED ✗'}
    ║  Results  : ${params.outdir}
    ║  QC tool  : ${params.qc_tool}
    ║  Assembler: ${params.assembler}
    ║  Duration : ${workflow.duration}
    ╚══════════════════════════════════════════════════════════════════╝

    """.stripIndent()
}

workflow.onError {
    log.error "Pipeline failed: ${workflow.errorMessage}"
}
