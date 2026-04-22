#!/usr/bin/env python3
"""Expense report summariser — reads a CSV, returns a short markdown summary."""
import csv
from collections import defaultdict


def summarise(csv_path: str) -> str:
    totals = defaultdict(float)
    rows = 0
    with open(csv_path, newline="") as fh:
        for row in csv.DictReader(fh):
            totals[row["category"]] += float(row["amount"])
            rows += 1

    top = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)[:3]
    body = "\n".join(f"- **{cat}**: £{amt:,.2f}" for cat, amt in top)
    return f"# Expense summary\n\n{rows} line items across {len(totals)} categories.\n\n{body}\n"


if __name__ == "__main__":
    import sys
    print(summarise(sys.argv[1]))
