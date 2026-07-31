/*
========================================================================================
    MODULE: BLASTP
    Performs protein homology search against a reference database using BLASTP.
========================================================================================
*/

process BLASTP {
    tag "${sample}"

    publishDir (
        path: "${params.outdir}/08_blastp/${sample}",
        mode: 'copy'
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(faa)   // Prokka .faa output
    path blastp_db                          // BLAST database (makeblastdb-formatted or raw FASTA)

    output:
    tuple val(sample), path("${sample}_blastp_best5_hits.tsv"),  emit: best5_hits
    tuple val(sample), path("${sample}_blastp_summary.tsv"),     emit: summary
    path "${sample}_blastp_report.txt",                          emit: report

    script:
    """
    # Step A: Check if the BLAST database is pre-formatted or raw FASTA 
    # If raw FASTA is provided, format it first with makeblastdb
    if [ ! -f "${blastp_db}.pin" ] && [ ! -f "${blastp_db}.pdb" ]; then
        echo "Formatting BLAST database from FASTA: ${blastp_db}"
        makeblastdb \\
            -in ${blastp_db} \\
            -dbtype prot \\
            -out blast_db \\
            -parse_seqids \\
            2>&1
        DB_PATH="blast_db"
    else
        DB_PATH="${blastp_db}"
    fi

    # Step B: Run BLASTP top 5 hits 
    echo "Running BLASTP for ${sample}..."

    # Tabular output (best 5 hits per query)
    blastp \\
        -query ${faa} \\
        -db \${DB_PATH} \\
        -out ${sample}_blastp_best5_hits.tsv \\
        -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" \\
        -max_target_seqs 5 \\
        -num_threads ${task.cpus} \\
        -evalue 1e-5 \\
        2>&1

    # Step C: Add header to tabular output 
   echo -e "qseqid\tsseqid\tpident\tlength\tmismatch\tgapopen\tqstart\tqend\tsstart\tsend\tevalue\tbitscore\tstitle" \\
        > ${sample}_blastp_best5_hits_header.tsv
    cat ${sample}_blastp_best5_hits_header.tsv ${sample}_blastp_best5_hits.tsv \\
        > tmp_hits.tsv && mv tmp_hits.tsv ${sample}_blastp_best5_hits.tsv

    # Step D: Parse hits into summary (best hit per query only) 
    python3 ${projectDir}/bin/parse_blastp.py \\
        --input  ${sample}_blastp_best5_hits.tsv \\
        --output ${sample}_blastp_summary.tsv \\
        --report ${sample}_blastp_report.txt \\
        --sample ${sample} \\
        --top    5

    echo "BLASTP complete for ${sample}:"
    echo "  Total queries : \$(grep -c '>' ${faa} || echo 0)"
    echo "  Hits returned : \$(wc -l < ${sample}_blastp_best5_hits.tsv)"
    """
}

