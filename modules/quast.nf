/*
========================================================================================
    MODULE: QUAST
    Assembly quality assessment using QUAST
========================================================================================
*/

process QUAST {
    tag "${sample}"
    label 'process_low'

    publishDir (
        path: "${params.outdir}/04_quast",
        mode: 'copy',
        saveAs: { filename -> "${sample}/${filename}" }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(assembly)

    output:
    tuple val(sample), path("${sample}_quast"),  emit: results
    path "${sample}_quast/report.tsv",           emit: tsv
    path "${sample}_quast/report.html",          emit: html

    script:
    """
    quast.py \\
        ${assembly} \\
        --output-dir ${sample}_quast \\
        --threads ${task.cpus} \\
        --min-contig ${params.min_contig_len} \\
        --labels ${sample} \\
        2>&1
    """
}
