/*
========================================================================================
    MODULE: NANOPLOT                                                        
    Performs quality control on raw and trimmed reads specifically optimised for
    Oxford Nanopore long reads.
========================================================================================
*/

process NANOPLOT {
    tag "${sample} [${stage}]"

    publishDir (
        path: "${params.outdir}/01_qc/nanoplot/${stage}",
        mode: 'copy',
        saveAs: { filename -> "${sample}/${filename}" }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(reads)
    val stage   // 'raw' or 'trimmed'

    output:
    tuple val(sample), path ("${sample}_nanoplot_${stage}"),                         emit: stats

    script:
    """
    # Run NanoPlot on the FASTQ file
    NanoPlot --fastq ${reads} \\
        --outdir ${sample}_nanoplot_${stage} \\
        --prefix ${stage}_${sample}_ \\
        --threads ${task.cpus} \\
        --plots dot \\
        --N50 \\
        --title "${stage} reads: [${sample}]" \\
        2>&1
     """
}
