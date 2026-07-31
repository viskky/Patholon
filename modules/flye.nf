/*
========================================================================================
    MODULE: FLYE
    De novo assembly of long Nanopore reads
========================================================================================
*/

process FLYE {
    tag "${sample}"
    label 'process_high'

    publishDir (
        path: "${params.outdir}/03_assembly/flye",
        mode: 'copy',
        saveAs: { filename ->
            if (filename.endsWith(".fasta"))  return "${sample}_assembly.fasta"
            if (filename.endsWith(".log"))    return "${sample}_flye.log"
            if (filename.endsWith(".gfa"))    return "${sample}_assembly_graph.gfa"
            if (filename.endsWith(".json"))   return "${sample}_assembly_info.json"
            return filename
        }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample), path("${sample}_flye/assembly.fasta"),        emit: assembly
    tuple val(sample), path("${sample}_flye/assembly_graph.gfa"),    emit: graph
    tuple val(sample), path("${sample}_flye/assembly_info.txt"),     emit: info
    path "${sample}_flye/flye.log",                                  emit: log

    script:
    """
    flye \\
        --nano-raw ${reads} \\
        --out-dir ${sample}_flye \\
        --genome-size ${params.genome_size} \\
        --threads ${task.cpus} \\
        --min-overlap 1000 \\
        2>&1

    # Copy assembly to named file for downstream processes
    cp ${sample}_flye/assembly.fasta ${sample}_assembly.fasta
    """
}
