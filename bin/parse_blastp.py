#!/usr/bin/env python3
"""
Parses BLASTP tabular output (outfmt 6) and produces:
  1. A clean summary TSV with the best hit per query
  2. A human-readable plain-text report

Usage:
    python3 parse_blastp.py \\
        --input  sample_blastp_best5_hits.tsv \\
        --output sample_blastp_summary.tsv \\
        --report sample_blastp_report.txt \\
        --sample SAMPLE_NAME \\
        --top    5
"""

import argparse
import sys
from pathlib import Path
from collections import defaultdict


# Expected column names from blastp -outfmt 6 with stitle
COLUMNS = [
    "qseqid", "sseqid", "pident", "length", "mismatch", "gapopen",
    "qstart", "qend", "sstart", "send", "evalue", "bitscore", "stitle"
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Parse BLASTP outfmt-6 output into summary TSV and report"
    )
    parser.add_argument("--input",  required=True, help="BLASTP outfmt 6 TSV (with header)")
    parser.add_argument("--output", required=True, help="Output summary TSV")
    parser.add_argument("--report", required=True, help="Output plain-text report")
    parser.add_argument("--sample", default="unknown", help="Sample name")
    parser.add_argument("--top",    type=int, default=5,
                        help="Number of top hits to retain per query [default: 5]")
    return parser.parse_args()


def read_blastp_table(input_path):
    """
    Read the tabular BLASTP output.
    Returns a dict: { query_id: [list of hit dicts, up to --top hits] }
    Skips the header line if present.
    """
    hits_by_query = defaultdict(list)
    total_lines   = 0

    with open(input_path) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("qseqid"):   # skip header
                continue
            parts = line.split("\t")
            # stitle may contain tabs itself; join remainder
            if len(parts) < 12:
                continue
            total_lines += 1

            record = {
                "qseqid":   parts[0],
                "sseqid":   parts[1],
                "pident":   float(parts[2]),
                "length":   int(parts[3]),
                "mismatch": int(parts[4]),
                "gapopen":  int(parts[5]),
                "qstart":   int(parts[6]),
                "qend":     int(parts[7]),
                "sstart":   int(parts[8]),
                "send":     int(parts[9]),
                "evalue":   float(parts[10]),
                "bitscore": float(parts[11]),
                "stitle":   "\t".join(parts[12:]) if len(parts) > 12 else "",
            }
            hits_by_query[record["qseqid"]].append(record)

    return hits_by_query, total_lines


def write_summary_tsv(hits_by_query, output_path, sample, top_n):
    """
    Write a summary TSV: best hit per query + all top-N hits.
    Columns: sample, query, hit_rank, sseqid, pident, length,
             evalue, bitscore, description
    """
    header = [
        "sample", "query_protein", "hit_rank", "subject_id",
        "pct_identity", "aln_length", "evalue", "bitscore", "description"
    ]

    with open(output_path, "w") as out:
        out.write("\t".join(header) + "\n")
        for query, hits in sorted(hits_by_query.items()):
            # BLASTP already returns hits sorted by bitscore (best first)
            for rank, hit in enumerate(hits[:top_n], start=1):
                row = [
                    sample,
                    query,
                    str(rank),
                    hit["sseqid"],
                    f"{hit['pident']:.1f}",
                    str(hit["length"]),
                    f"{hit['evalue']:.2e}",
                    f"{hit['bitscore']:.1f}",
                    hit["stitle"]
                ]
                out.write("\t".join(row) + "\n")


def write_report(hits_by_query, report_path, sample, top_n, total_lines):
    """
    Write a human-readable plain-text report summarising BLASTP results.
    """
    total_queries = len(hits_by_query)
    no_hit_count  = 0   # queries with zero hits (not in table at all)
    # Note: queries with zero hits won't appear in hits_by_query

    with open(report_path, "w") as out:
        out.write("=" * 70 + "\n")
        out.write(f"  BLASTP REPORT — {sample}\n")
        out.write("=" * 70 + "\n\n")
        out.write(f"  Top hits reported per query : {top_n}\n")
        out.write(f"  Total BLASTP hit lines      : {total_lines}\n")
        out.write(f"  Queries with ≥1 hit         : {total_queries}\n\n")
        out.write("-" * 70 + "\n")
        out.write(f"  {'QUERY PROTEIN':<35} {'RANK':>4}  {'%ID':>6}  "
                  f"{'LEN':>5}  {'E-VALUE':>10}  DESCRIPTION\n")
        out.write("-" * 70 + "\n")

        for query, hits in sorted(hits_by_query.items()):
            for rank, hit in enumerate(hits[:top_n], start=1):
                desc = hit["stitle"][:50] + "..." if len(hit["stitle"]) > 50 else hit["stitle"]
                out.write(
                    f"  {query:<35} {rank:>4}  {hit['pident']:>6.1f}  "
                    f"{hit['length']:>5}  {hit['evalue']:>10.2e}  {desc}\n"
                )
            out.write("\n")

        out.write("=" * 70 + "\n")
        out.write("  End of report\n")
        out.write("=" * 70 + "\n")


def main():
    args = parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    hits_by_query, total_lines = read_blastp_table(input_path)

    if not hits_by_query:
        print(f"[{args.sample}] WARNING: No BLASTP hits found in {input_path}.")
        # Write empty outputs so the pipeline doesn't fail
        Path(args.output).write_text(
            "sample\tquery_protein\thit_rank\tsubject_id\tpct_identity\t"
            "aln_length\tevalue\tbitscore\tdescription\n"
        )
        Path(args.report).write_text(
            f"BLASTP REPORT — {args.sample}\nNo hits found.\n"
        )
        return

    write_summary_tsv(hits_by_query, args.output, args.sample, args.top)
    write_report(hits_by_query, args.report, args.sample, args.top, total_lines)

    print(f"[{args.sample}] BLASTP parsing complete:")
    print(f"  Total hit lines          : {total_lines}")
    print(f"  Queries with hits        : {len(hits_by_query)}")
    print(f"  Top hits retained/query  : {args.top}")
    print(f"  Summary TSV written to   : {args.output}")
    print(f"  Report written to        : {args.report}")


if __name__ == "__main__":
    main()
