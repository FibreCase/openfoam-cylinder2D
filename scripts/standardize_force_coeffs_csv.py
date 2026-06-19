#!/usr/bin/env python3
"""Convert OpenFOAM forceCoeffs output into a standard CSV file.

The source file usually contains metadata lines that start with ``#`` and a
header row that is also commented out. This script keeps the data table, turns
the commented header into a real CSV header, and writes comma-separated output.
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import re
import sys


def split_row(line: str) -> list[str]:
    """Split a whitespace-delimited row into fields."""

    return re.split(r"\s+", line.strip())


def standardize_force_coeffs_csv(input_path: pathlib.Path, output_path: pathlib.Path) -> None:
    header: list[str] | None = None
    rows: list[list[str]] = []

    with input_path.open("r", encoding="utf-8", newline="") as source:
        for raw_line in source:
            line = raw_line.strip()
            if not line:
                continue

            if line.startswith("#"):
                candidate = line.lstrip("#").strip()
                if candidate and candidate.lower().startswith("time"):
                    header = split_row(candidate)
                continue

            if header is None and line.lower().startswith("time"):
                header = split_row(line)
                continue

            rows.append(split_row(line))

    if header is None:
        raise ValueError(f"No CSV header found in {input_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as target:
        writer = csv.writer(target)
        writer.writerow(header)
        writer.writerows(rows)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Standardize an OpenFOAM forceCoeffs text export into CSV format.")
    parser.add_argument("input", type=pathlib.Path, help="Path to the source file")
    parser.add_argument(
        "-o",
        "--output",
        type=pathlib.Path,
        help="Path to the output CSV file (default: same name with .csv suffix)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    input_path = args.input
    output_path = args.output or input_path.with_suffix(".csv")

    standardize_force_coeffs_csv(input_path, output_path)
    print(f"Wrote standardized CSV to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())