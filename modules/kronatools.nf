/*
========================================================================================
    MODULE: KRONATOOLS
    Generates interactive taxonomic abundance charts from Kraken2 reports
========================================================================================
*/

process KRONATOOLS {
    tag "${sample}"
    label 'process_low'

    publishDir (
        path: "${params.outdir}/10_krona",
        mode: 'copy'
    )

    conda "${projectDir}/environment.yml"

    input:
    tuple val(sample), path(kraken2_report)

    output:
    tuple val(sample), path("${sample}_krona.html"), emit: html
    path "${sample}_krona.html",                     emit: html_only

    script:
    """
       set -e

    echo "========================================"
    echo "Checking Krona taxonomy"
    echo "========================================"

    KRONA_TAXONOMY="\${CONDA_PREFIX}/opt/krona/taxonomy"

    echo "Krona taxonomy directory:"
    echo "\$KRONA_TAXONOMY"

    # The Bioconda Krona package contains a 'placeholder'
    # file when the taxonomy database has NOT been initialized.
    if [ ! -d "\$KRONA_TAXONOMY" ] || \
       [ -f "\$KRONA_TAXONOMY/placeholder" ] || \
       [ -z "\$(find "\$KRONA_TAXONOMY" -type f ! -name placeholder -print -quit 2>/dev/null)" ]; then

        echo "Krona taxonomy database is missing or not initialized."
        echo "Updating Krona taxonomy database..."

        ktUpdateTaxonomy.sh

    else

        echo "Krona taxonomy database found."
        echo "Using existing taxonomy database."

    fi

    echo "========================================"
    echo "Taxonomy directory after update/check"
    echo "========================================"

    ls -lah "\$KRONA_TAXONOMY"

    echo "========================================"
    echo "Generating Krona chart"
    echo "========================================"
 
	# Convert Kraken2 report to Krona input format

    # Generate Krona chart
    ktImportTaxonomy \\
        -t 7 \\
        -m 3 \\
        -o ${sample}_krona.html \\
        ${kraken2_report} \\
        2>&1

    echo "Krona chart generated: ${sample}_krona.html"
    """
}


