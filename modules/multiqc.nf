/*
========================================================================================
    MODULE: MULTIQC
    Aggregates QC results from FastQC, QUAST, Kraken2 into a unified HTML report
========================================================================================
*/

process MULTIQC {
    label 'process_low'

    publishDir (
        path: "${params.outdir}/11_multiqc",
        mode: 'copy'
    )

    conda "${projectDir}/environment.yml"

    input:
    path multiqc_files   // Collected QC output files

    output:
    path "multiqc_report.html",  emit: html
    path "multiqc_report_data",        emit: data

    script:
    def config = params.multiqc_config ? "--config ${params.multiqc_config}" : ""
    def title  = params.multiqc_title  ? "--title \"${params.multiqc_title}\"" : ""
    """
    multiqc .  \\
	--outdir . \\
	-n multiqc_report.html  \\
        ${config} \\
        ${title} \\
	--verbose \\
        2>&1
    """
}
