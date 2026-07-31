#!/usr/bin/env python3

"""
========================================================================================
parse_amr_result.py

Visualise ABRicate AMR / plasmid results as a heatmap.
========================================================================================
"""

import argparse
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt


def create_empty_plot(output_file):
    """
    Create placeholder image when no genes are detected.
    """

    plt.figure(figsize=(7, 2.5))

    plt.text(
        0.5,
        0.5,
        "No AMR or Plasmid or Virulence Genes detected",
        ha="center",
        va="center",
        fontsize=14
    )

    plt.title("Patholon Analysis")
    plt.axis("off")

    plt.savefig(
        output_file,
        dpi=300,
        bbox_inches="tight"
    )

    plt.close()


def main():

    parser = argparse.ArgumentParser(
        description="Generate heatmap from ABRicate TSV results"
    )

    parser.add_argument(
        "--input",
        required=True,
        help="ABRicate TSV file"
    )

    parser.add_argument(
        "--output",
        required=True,
        help="Output TIFF file"
    )

    args = parser.parse_args()

    try:

        df = pd.read_csv(
            args.input,
            sep="\t"
        )

        df.columns = df.columns.str.replace("^#", "", regex=True)
        df.columns = df.columns.str.strip()

    except Exception as e:

        print(f"Error reading TSV file: {e}")

        create_empty_plot(args.output)

        return

    if df.empty:

        print("No genes detected: empty dataframe")

        create_empty_plot(args.output)

        return

    if "GENE" not in df.columns:

        print("Missing GENE column")

        create_empty_plot(args.output)

        return

    df = df.dropna(subset=["GENE"])

    if df.empty:

        print("No valid genes detected")

        create_empty_plot(args.output)

        return

    if "RESISTANCE" in df.columns and not df["RESISTANCE"].isna().all():

        grouping_col = "RESISTANCE"
        ylabel = "Resistance"

    elif "SEQUENCE" in df.columns:

        grouping_col = "SEQUENCE"
        ylabel = "Sequence"

    else:

        df["GROUP"] = "Detected Genes"

        grouping_col = "GROUP"
        ylabel = "Category"

    try:

        matrix = df.pivot_table(
            index=grouping_col,
            columns="GENE",
            aggfunc="size",
            fill_value=0
        )

    except Exception as e:

        print(f"Error creating matrix: {e}")

        create_empty_plot(args.output)

        return

    if matrix.empty:

        print("Empty matrix generated")

        create_empty_plot(args.output)

        return

    plt.figure(
        figsize=(
            max(10, matrix.shape[1] * 0.5),
            max(4, matrix.shape[0] * 0.5)
        )
    )

    sns.heatmap(
        matrix,
        cmap="Reds",
        linewidths=0.5,
        annot=True
    )

    plt.title(
        "Functional Gene Detection Heatmap (PATHOLON)",
        fontsize=14
    )

    plt.ylabel(ylabel, fontsize=12)

    plt.xlabel("Gene Name", fontsize=12)

    plt.xticks(rotation=45, ha="right")

    plt.tight_layout()

    plt.savefig(
        args.output,
        dpi=300,
        bbox_inches="tight"
    )

    plt.close()

    print(f"Plot saved: {args.output}")


if __name__ == "__main__":
    main()
