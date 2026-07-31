/*
========================================================================================
    MODULE: ABRICATE
    Screens contigs for genes using ABRicate databases
========================================================================================
*/

process ABRICATE_AMR {
    tag "${sample}"
    label 'process_low'

    publishDir (
        path: "${params.outdir}/06_abricate/amr",
        mode: 'copy',
        saveAs: { filename -> "${sample}/${filename}" }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(assembly)

    output:
    tuple val(sample), path("${sample}_abricate_amr.tsv"), emit: report
	tuple val(sample), path("${sample}_abricate_amr.tiff"), emit: tiff
    path "${sample}_abricate_amr.tsv",                     emit: tsv_only

    script:
    """
    abricate \\
        --db ${params.abricate_db} \\
        --minid 80 \\
        --mincov 60 \\
        --threads ${task.cpus} \\
        ${assembly} \\
        > ${sample}_abricate_amr.tsv

	
	python3 ${projectDir}/bin/parse_amr_result.py \
        --input ${sample}_abricate_amr.tsv \
        --output ${sample}_abricate_amr.tiff

    echo "ABRicate results for ${sample}:"
    wc -l ${sample}_abricate_amr.tsv
    """
}

process ABRICATE_PLASMID {
    tag "${sample}"
    label 'process_low'

    publishDir (
        path: "${params.outdir}/06_abricate/plasmid",
        mode: 'copy',
        saveAs: { filename -> "${sample}/${filename}" }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(assembly)

    output:
    tuple val(sample), path("${sample}_abricate_plasmid.tsv"), emit: report
	tuple val(sample), path("${sample}_abricate_plasmid.tiff"), emit: tiff
    path "${sample}_abricate_plasmid.tsv",                     emit: tsv_only

    script:
    """
    abricate \\
        --db plasmidfinder \\
        --minid 80 \\
        --mincov 60 \\
        --threads ${task.cpus} \\
        ${assembly} \\
        > ${sample}_abricate_plasmid.tsv

	python3 ${projectDir}/bin/parse_amr_result.py \
        --input ${sample}_abricate_plasmid.tsv \
        --output ${sample}_abricate_plasmid.tiff
		
    echo "ABRicate results for ${sample}:"
    wc -l ${sample}_abricate_plasmid.tsv
    """
}


