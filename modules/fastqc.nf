/*
========================================================================================
    MODULE: FASTQC
    Performs quality control on raw and trimmed FASTQ reads
========================================================================================
*/

process FASTQC {
    tag "${sample} [${stage}]"
    label 'process_low'

    publishDir (
        path: "${params.outdir}/01_qc/fastqc/${stage}",
        mode: 'copy',
        saveAs: { filename -> filename }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(reads)
    val stage   // 'raw' or 'trimmed'

    output:
    tuple val(sample), path("*.html"), emit: html
    tuple val(sample), path("*.zip"),  emit: zip

    script:
    """
    fastqc --outdir .  \\
        --threads ${task.cpus} \\
        ${reads}
    """
}
