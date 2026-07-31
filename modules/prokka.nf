/*
========================================================================================
    MODULE: PROKKA
    Rapid prokaryotic genome annotation
========================================================================================
*/

process PROKKA {
    tag "${sample}"
    label 'process_medium'

    publishDir (
        path: "${params.outdir}/05_prokka",
        mode: 'copy',
        saveAs: { filename -> "${sample}/${filename}" }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(assembly)

    output:
    tuple val(sample), path("${sample}_prokka/${sample}.gff"),  emit: gff
    tuple val(sample), path("${sample}_prokka/${sample}.faa"),  emit: faa
    tuple val(sample), path("${sample}_prokka/${sample}.fna"),  emit: fna
    tuple val(sample), path("${sample}_prokka/${sample}.gbk"),  emit: gbk
    tuple val(sample), path("${sample}_prokka/${sample}.ffn"),  emit: ffn
    path "${sample}_prokka/${sample}.txt",                      emit: stats

    script:
    """
    prokka \\
        --outdir ${sample}_prokka \\
        --prefix ${sample} \\
        --cpus ${task.cpus} \\
        --mincontiglen ${params.min_contig_len} \\
        --force \\
        ${assembly} \\
        2>&1
    """
}
