/*
========================================================================================
    MODULE: KRAKEN2
    Taxonomic classification of reads using Kraken2 k-mer database
========================================================================================
*/

process KRAKEN2 {
    tag "${sample}"
    label 'process_high'

    publishDir (
        path: "${params.outdir}/09_kraken2",
        mode: 'copy',
        saveAs: { filename -> "${sample}/${filename}" }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(reads)
    path kraken2_db    

    output:
    tuple val(sample), path("${sample}_kraken2_report.txt"),      emit: report
    tuple val(sample), path("${sample}_kraken2_output.txt.gz"),   emit: output
    tuple val(sample), path("${sample}_classified.fastq.gz"),     emit: classified
    tuple val(sample), path("${sample}_unclassified.fastq.gz"),   emit: unclassified
    path "${sample}_kraken2_report.txt",                          emit: report_only

    script:
    """
    kraken2 \\
        --db ${kraken2_db} \\
        --threads ${task.cpus} \\
        --report ${sample}_kraken2_report.txt \\
        --report-minimizer-data \\
        --classified-out ${sample}_classified.fastq \\
        --unclassified-out ${sample}_unclassified.fastq \\
        --output ${sample}_kraken2_output.txt \\
        --gzip-compressed \\
        ${reads} \\
        2>&1

    # Compress outputs to save space
    gzip ${sample}_classified.fastq
    gzip ${sample}_unclassified.fastq
    gzip ${sample}_kraken2_output.txt

    echo "Classification summary for ${sample}:"
    head -20 ${sample}_kraken2_report.txt
    """
}
