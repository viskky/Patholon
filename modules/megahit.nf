/*
========================================================================================
    MODULE: MEGAHIT
    De novo assembly using MEGAHIT (alternative to Flye for short read metagenomes)
========================================================================================
*/

process MEGAHIT {
    tag "${sample}"
    label 'process_high'

    publishDir (
        path: "${params.outdir}/03_assembly/megahit",
        mode: 'copy',
        saveAs: { filename ->
            if (filename.endsWith(".fa"))  return "${sample}_assembly.fasta"
            if (filename.endsWith(".log")) return "${sample}_megahit.log"
            return filename
        }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample), path("${sample}_megahit/${sample}.contigs.fa"), emit: assembly
    path "${sample}_megahit/${sample}.log",                                  emit: log

    script:
    """
    # Convert FASTQ to appropriate format for MEGAHIT
    megahit \\
        -r ${reads} \\
        --out-dir ${sample}_megahit \\
        --out-prefix ${sample} \\
        --min-contig-len ${params.min_contig_len} \\
        --num-cpu-threads ${task.cpus} \\
        2>&1

    # Rename for clarity
    cp ${sample}_megahit/${sample}.contigs.fa ${sample}_assembly.fasta
    """
}
