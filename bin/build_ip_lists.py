#!bin/env/bin/python3
"""
build_ip_lists.py - Scans all CSV files in a directory for public IP addresses
and produces three summary files.

Creates:
  ip-addresses.txt              unique IPs, one per line
  ip-addresses.csv              unique IPs with geo data and occurrence count
  ip-addresses-timestamp.csv    one row per occurrence: Timestamp, IPAddress

Usage:
    python build_ip_lists.py --process-dir <directory>
"""
import argparse
import csv
import ipaddress
import re

import chardet
from pathlib import Path

from geoip2 import database

IP_DB_FILE = Path.home() / ".ip-db-full.mmb"

IPV4_RE = re.compile(r"\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b")
IPV6_RE = re.compile(r"\b(?:[0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}\b")

TIMESTAMP_KEYWORDS = {"time", "date", "timestamp", "created", "modified", "accessed"}

SKIP_FILES = {"ip-addresses.csv", "ip-addresses-timestamp.csv", "ip-addresses.txt", "Timeline.csv"}


def is_public_ip(ip_str):
    try:
        if ip_str.split(".")[3] == "0":
            return False
    except:
        pass
    try:
        return ipaddress.ip_address(ip_str).is_global
    except ValueError:
        return False


def looks_like_filepath(value):
    return bool(re.search(r'[/\\]', value))


def ip_is_embedded(value, match):
    """Check if the IP match is embedded inside a larger token (e.g. version string in a filename)."""
    start, end = match.start(), match.end()
    before = value[start - 1] if start > 0 else " "
    after = value[end] if end < len(value) else " "
    # A dot immediately adjacent means this is part of a longer dotted sequence (version/domain)
    if before == "." or after == ".":
        return True
    # Both sides must be non-clean to consider it embedded (AND logic).
    # ":" covers port suffixes (1.2.3.4:80); ">" covers HTML-encoded arrows (&gt;) in event payloads.
    clean_boundary = {" ", ",", "\t", '"', "'", "(", ")", "[", "]", "", ":", ">", "<"}
    return before not in clean_boundary and after not in clean_boundary


def _looks_like_version(ip_str, cell_value):
    """Return True if the dotted-quad looks like a version number rather than a routable IP.

    Two heuristics:
    1. Any non-last octet is 0 → network/version address (e.g. 1.28.0.1, 2.0.0.31).
    2. The entire cell IS this IP, and both first and second octets are ≤ 9 → standalone version
       string in filesystem metadata (e.g. "1.3.229.3", "1.4.8.1" as MFT filenames).
       This rule is only applied when standalone so that real IPs like 8.8.8.8 in event log
       descriptions are not incorrectly filtered.
    """
    octets = ip_str.split(".")
    if any(o == "0" for o in octets[:3]):
        return True
    if cell_value.strip() == ip_str and int(octets[0]) <= 9 and int(octets[1]) <= 9:
        return True
    return False


def extract_ip(value):
    if looks_like_filepath(value) or "version" in value.lower() or "revision" in value.lower() or "oid" in value.lower():
        return ""
    for m in IPV4_RE.finditer(value):
        ip = m.group(0)
        if not all(0 <= int(g) <= 255 for g in m.groups()):
            continue
        if not is_public_ip(ip):
            print(f"  Ignoring {ip}, not a public IP")
            continue
        if ip_is_embedded(value, m):
            print(f"  Ignoring {ip}, embedded in larger token")
            continue
        if _looks_like_version(ip, value):
            print(f"  Ignoring {ip}, looks like a version number")
            continue
        return ip
    for m in IPV6_RE.finditer(value):
        if is_public_ip(m.group(0)):
            return m.group(0)
    return ""


def is_timestamp_column(name):
    return any(kw in name.lower() for kw in TIMESTAMP_KEYWORDS)


def lookup_ip(db, ip):
    if not ip:
        return "", "", "", ""
    try:
        res = db.enterprise(ip)
        country = str(res.country.names.get("en", "")).replace("None", "")
        city = str(res.city.names.get("en", "")).replace("None", "")
        ip_type = str(res.traits.connection_type).replace("None", "")
        isp = str(res.traits.isp).replace("None", "")
        return country, city, ip_type, isp
    except Exception:
        return "", "", "", ""


def main():
    parser = argparse.ArgumentParser(description="Build IP address lists from CSV files")
    parser.add_argument("--process-dir", required=True, help="Directory with CSV files to scan")
    args = parser.parse_args()

    process_dir = Path(args.process_dir)

    if not IP_DB_FILE.exists():
        print(f"Warning: IP database not found at {IP_DB_FILE}, skipping geo lookup")
        db_ctx = None
    else:
        try:
            db_ctx = database.Reader(IP_DB_FILE)
        except Exception as e:
            print(f"Warning: Could not open IP database ({e}), skipping geo lookup")
            db_ctx = None

    ip_data = {}          # ip -> [country, city, ip_type, isp, count]
    ip_timestamp_rows = []  # (timestamp, ip) for every occurrence

    for csv_file in sorted(process_dir.glob("*.csv")):
        if csv_file.name in SKIP_FILES:
            continue

        detected = chardet.detect(csv_file.read_bytes())["encoding"]
        encoding = detected if detected and detected.lower() not in ("ascii", "utf-8") else "utf-8-sig"
        with open(csv_file, newline="", encoding=encoding, errors="replace") as f:
            rows = list(csv.reader(f))

        if not rows:
            continue

        header = rows[0]
        ts_indices = [i for i, col in enumerate(header) if is_timestamp_column(col)]

        print(f"Scanning {csv_file.name}...")

        for row in rows[1:]:
            if not row:
                continue
            ip = next((extract_ip(cell) for i, cell in enumerate(row)
                       if i not in ts_indices and extract_ip(cell)), "")
            if not ip:
                continue
            timestamp = row[ts_indices[0]] if ts_indices and ts_indices[0] < len(row) else ""
            country, city, ip_type, isp = lookup_ip(db_ctx, ip) if db_ctx else ("", "", "", "")
            if ip not in ip_data:
                ip_data[ip] = [country, city, ip_type, isp, 0]
                print(f"  Public IP: {ip}")
            ip_data[ip][4] += 1
            ip_timestamp_rows.append((timestamp, ip, country, city, ip_type, isp))

    if db_ctx:
        db_ctx.close()

    ip_txt = process_dir / "ip-addresses.txt"
    with open(ip_txt, "w", encoding="utf-8") as f:
        for ip in sorted(ip_data.keys()):
            f.write(ip + "\n")
    print(f"Wrote {len(ip_data)} unique IPs to {ip_txt.name}")

    ip_csv = process_dir / "ip-addresses.csv"
    with open(ip_csv, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(["IPAddress", "Nbr occurance", "Country", "City", "Type", "ISP"])
        for ip, (country, city, ip_type, isp, count) in ip_data.items():
            writer.writerow([ip, count, country, city, ip_type, isp])
    print(f"Wrote {len(ip_data)} rows to {ip_csv.name}")

    ip_ts_csv = process_dir / "ip-addresses-timestamp.csv"
    with open(ip_ts_csv, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(["Timestamp", "IPAddress", "Country", "City", "Type", "ISP"])
        writer.writerows(sorted(ip_timestamp_rows, key=lambda r: r[0]))
    print(f"Wrote {len(ip_timestamp_rows)} rows to {ip_ts_csv.name}")


if __name__ == "__main__":
    main()
