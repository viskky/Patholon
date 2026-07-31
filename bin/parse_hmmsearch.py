#!/usr/bin/env python3
"""
parse_hmmsearch.py
==================
Parses HMMER hmmsearch --tblout output and filters hits by E-value and score.
Outputs a clean TSV with phage-associated protein or domain hits.

Usage:
    python3 parse_hmmsearch.py \\
        --tblout sample_phage_hits.tblout \\
        --output sample_phage_hits_filtered.tsv \\
        --evalue 1e-10 \\
        --score 30 \\
        --sample SAMPLE_NAME
"""

import argparse
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Filter and format HMMsearch tblout results for phage domain hits"
    )
    parser.add_argument("--tblout",  required=True, help="HMMsearch tblout file")
    parser.add_argument("--output",  required=True, help="Output filtered TSV")
    parser.add_argument("--evalue",  type=float, default=1e-10,
                        help="Maximum E-value threshold [default: 1e-10]")
    parser.add_argument("--score",   type=float, default=30.0,
                        help="Minimum bit score [default: 30]")
    parser.add_argument("--sample",  default="unknown", help="Sample name for output")
    return parser.parse_args()


def parse_tblout(tblout_path, evalue_thresh, score_thresh, sample_name):
    """Parse hmmsearch --tblout format and yield filtered hit records."""
    hits = []
    total = 0

    with open(tblout_path) as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 19:
                continue

            total += 1
            target_name  = parts[0]   # Protein/query sequence name
            query_name   = parts[2]   # HMM profile name
            full_evalue  = float(parts[4])
            full_score   = float(parts[5])
            full_bias    = float(parts[6])
            best_evalue  = float(parts[7])
            best_score   = float(parts[8])
            description  = " ".join(parts[18:])

            if full_evalue <= evalue_thresh and full_score >= score_thresh:
                hits.append({
                    "sample":       sample_name,
                    "protein_id":   target_name,
                    "hmm_profile":  query_name,
                    "full_evalue":  full_evalue,
                    "full_score":   full_score,
                    "full_bias":    full_bias,
                    "best_evalue":  best_evalue,
                    "best_score":   best_score,
                    "description":  description,
                })

    return hits, total


def write_output(hits, output_path, sample_name):
    """Write filtered hits to TSV."""
    header = [
        "sample", "protein_id", "hmm_profile",
        "full_evalue", "full_score", "full_bias",
        "best_evalue", "best_score", "description"
    ]

    with open(output_path, "w") as out:
        out.write("\t".join(header) + "\n")
        for h in hits:
            row = [
                h["sample"],
                h["protein_id"],
                h["hmm_profile"],
                f"{h['full_evalue']:.2e}",
                f"{h['full_score']:.1f}",
                f"{h['full_bias']:.1f}",
                f"{h['best_evalue']:.2e}",
                f"{h['best_score']:.1f}",
                h["description"]
            ]
            out.write("\t".join(row) + "\n")


def main():
    args = parse_args()

    tblout_path = Path(args.tblout)
    if not tblout_path.exists():
        print(f"ERROR: tblout file not found: {tblout_path}", file=sys.stderr)
        sys.exit(1)

    hits, total = parse_tblout(tblout_path, args.evalue, args.score, args.sample)
    write_output(hits, args.output, args.sample)

    print(f"[{args.sample}] HMMsearch parsing complete:")
    print(f"  Total hits      : {total}")
    print(f"  Filtered hits   : {len(hits)}")
    print(f"  E-value cutoff  : {args.evalue}")
    print(f"  Score cutoff    : {args.score}")
    print(f"  Output written  : {args.output}")

    if len(hits) == 0:
        print("  NOTE: No phage-associated protein or domain hits passed the filters.")


if __name__ == "__main__":
    main()
