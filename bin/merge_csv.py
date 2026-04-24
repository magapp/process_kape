#!bin/env/bin/python3
"""
merge_csv.py - Merges KAPE-parsed CSV files from multiple hosts into combined per-type CSV files.

Usage:
    python merge_csv.py --process-dir <directory>

The process directory is expected to contain subdirectories named on the format
<timestamp>_<hostname> (e.g. "2026-03-26T083935_SERVER2022"), each containing
CSV files produced by KAPE. CSV files with the same name across subdirectories
are merged into a single file in the process directory root.
"""
import argparse
import csv
from pathlib import Path

import chardet
from dateutil import parser as dateutil_parser

# Column name keywords used to identify timestamp columns for normalization
TIMESTAMP_KEYWORDS = {"time", "date", "timestamp", "created", "modified", "accessed"}


def normalize_timestamp(value):
    """Parse a timestamp string and return it formatted as yyyy-mm-dd HH:MM:SS.
    Returns the original value unchanged if parsing fails."""
    try:
        return dateutil_parser.parse(value).strftime("%Y-%m-%d %H:%M:%S")
    except (ValueError, TypeError, OverflowError):
        return value


def is_timestamp_column(name):
    """Return True if the column name contains a timestamp-related keyword."""
    return any(kw in name.lower() for kw in TIMESTAMP_KEYWORDS)


def main():
    parser = argparse.ArgumentParser(description="Merge CSV files")
    parser.add_argument("--process-dir", required=True, help="Directory to process")
    args = parser.parse_args()

    process_dir = Path(args.process_dir)

    # Collect all CSV files recursively (KAPE places output in subdirectories)
    csv_files = [
        f
        for subdir in process_dir.iterdir()
        if subdir.is_dir() and subdir.name != "zip"
        for f in subdir.rglob("*.csv")
    ]

    print(f"Found {len(csv_files)} CSV files to merge in {process_dir}")

    for f in csv_files:
        # Subdirectory name format: <timestamp>_<hostname>
        parts = f.parent.name.split("_", 1)
        hostname = parts[1] if len(parts) > 1 else parts[0]
        print(f"  Processing: {f.relative_to(process_dir)} (hostname: {hostname})")

        output_file = process_dir / f.name
        file_exists = output_file.exists()

        # Auto-detect encoding; fall back to latin-1 to handle any byte value
        raw_bytes = f.read_bytes()
        detected = chardet.detect(raw_bytes)["encoding"]
        encoding = detected if detected and detected.lower() != "ascii" else "latin-1"
        print(f"    Encoding: {detected} -> using {encoding}, size: {len(raw_bytes)} bytes")

        with open(f, newline="", encoding=encoding) as src:
            reader = csv.reader(src)
            rows = list(reader)

        if not rows:
            print(f"    Skipping: empty file")
            continue

        header, data_rows = rows[0], rows[1:]
        print(f"    Columns: {len(header)}, rows: {len(data_rows)}")

        # Identify which column indices contain timestamps
        ts_indices = [i for i, col in enumerate(header) if is_timestamp_column(col)]
        if ts_indices:
            ts_cols = [header[i] for i in ts_indices]
            print(f"    Normalizing timestamp columns: {', '.join(ts_cols)}")

        # Normalize all timestamp cells to a consistent format
        normalized_rows = []
        for row in data_rows:
            row = list(row)
            for i in ts_indices:
                if i < len(row):
                    row[i] = normalize_timestamp(row[i])
            normalized_rows.append(row)
        data_rows = normalized_rows

        # Append hostname column to each row
        data_rows = [row + [hostname] for row in data_rows]

        # Append to the merged output file; write header only for new files
        with open(output_file, "a", newline="", encoding="utf-8-sig") as dst:
            writer = csv.writer(dst)
            if not file_exists:
                writer.writerow(header)
            writer.writerows(data_rows)

        action = "Created" if not file_exists else "Appended to"
        print(f"    {action}: {output_file.name} ({len(data_rows)} rows)")

    print(f"Merge complete.")


if __name__ == "__main__":
    main()
