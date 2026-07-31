/*
========================================================================================
    MODULE: HMMSEARCH
    Detects annotated protein families in HMM profiles
========================================================================================
*/

process HMMSEARCH {
    tag "${sample}"
    label 'process_medium'

    publishDir (
        path: "${params.outdir}/07_hmmsearch",
        mode: 'copy',
        saveAs: { filename -> "${sample}/${filename}" }
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(proteins_faa)  // Protein FASTA from Prokka
    path hmm_db                            // HMM profile database

    output:
    tuple val(sample), path("${sample}_phage_hits.tblout"),       emit: tblout
    tuple val(sample), path("${sample}_phage_hits_filtered.tsv"), emit: filtered
    path "${sample}_hmmsearch.log",                               emit: log

    script:
    """
    # Run HMMsearch against phage-like protein HMM profiles
    hmmpress ${hmm_db}

    hmmsearch \\
        --tblout ${sample}_phage_hits.tblout \\
        --cpu ${task.cpus} \\
        -E 1e-5 \\
        --domE 1e-5 \\
        ${hmm_db} \\
        ${proteins_faa} \\
        > ${sample}_hmmsearch.log 2>&1

    # Parse and filter significant hits (E-value < 1e-10, score > 30)
    python3 ${projectDir}/bin/parse_hmmsearch.py \\
        --tblout ${sample}_phage_hits.tblout \\
        --output ${sample}_phage_hits_filtered.tsv \\
        --evalue 1e-10 \\
        --score 30 \\
        --sample ${sample}

    echo "Phage-like protein hits for ${sample}:"
    wc -l ${sample}_phage_hits_filtered.tsv
    """
}
