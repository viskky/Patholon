/*
========================================================================================
    MODULE: PORECHOP
    Trims adapters and barcodes from Long sequencing reads
========================================================================================
*/

process PORECHOP {
    tag "${sample}"
    label 'process_medium'

    publishDir (
        path: "${params.outdir}/02_porechop",
        mode: 'copy',
        pattern: "*.log"
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample), path("${sample}_trimmed.fastq.gz"), emit: trimmed
    path "${sample}_porechop.log",                         emit: log

    script:
    """
    porechop --input ${reads} \\
        --output ${sample}_trimmed.fastq.gz \\
        --threads ${task.cpus} \\
        --min_split_read_size ${params.min_read_len} \\
        2>&1 | tee ${sample}_porechop.log

    """
}

