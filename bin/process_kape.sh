#!/bin/bash

# This script must be run inside the Docker container
if [ ! -f /.dockerenv ]; then
    echo "Error: This script must be run inside the Docker container." >&2
    echo "  docker exec -it kape-parser bash bin/process_kape.sh <args>" >&2
    exit 1
fi

input_directory="$1"
process_directory="$2"
output_directory="$3"
title="$4"

PARSE_MODULES_DIR="bin/kape/parse_modules"
ERRORS=0

LOCK_FILE="${input_directory}/run.lock"
MAX_AGE=36000  # 10 hour in seconds

run_cmd() {
    echo "Run: $*"
    "$@"
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: Command failed (exit code $rc): $*" >&2
        ERRORS=$((ERRORS + 1))
    fi
    return $rc
}

if ! which unzip &> /dev/null; then
    echo "Error: 'unzip' is not installed or not in PATH" >&2
    exit 1
fi

if ! which wine &> /dev/null; then
    echo "Error: 'wine' is not installed or not in PATH" >&2
    exit 1
fi

if [ ! -f bin/kape/kape.exe ]; then
    echo "Error: bin/kape/kape.exe not found" >&2
    exit 1
fi

if [ ! -f /root/.wine/drive_c/pwsh/pwsh.exe ]; then
    echo "Error: PowerShell (pwsh.exe) not found at /root/.wine/drive_c/pwsh/pwsh.exe" >&2
    exit 1
fi

if [ ! -d "$PARSE_MODULES_DIR" ]; then
    echo "Error: Directory $PARSE_MODULES_DIR not found, so I cant find parse modules" >&2
    exit 1
fi

# input_directory is typical "downloaded"
# process_directory is a temporary dir, where unzip and processing will occur
# output_directory is where downloadable result will be
# title is a name for the project
USAGE="Usage: process_kape.sh <input directory> <process_directory> <output directory> <title>"
if [ ! -d "$input_directory" ]; then
    echo "Error: input directory '$input_directory' does not exist" >&2
    echo $USAGE
    exit 1
fi

if [ ! -d "$process_directory" ]; then
    echo "Error: process directory '$process_directory' does not exist" >&2
    echo $USAGE
    exit 1
fi

if [ ! -d "$output_directory" ]; then
    echo "Error: output directory '$output_directory' does not exist" >&2
    echo $USAGE
    exit 1
fi

if [ -z "$title" ]; then
    echo "Error: title is required" >&2
    echo $USAGE
    exit 1
fi

# Check that there are zip files to process
zip_count=$(ls "$input_directory"/*.zip 2>/dev/null | wc -l)
if [ "$zip_count" -eq 0 ]; then
    echo "Error: No zip files found in $input_directory" >&2
    exit 1
fi
echo "Found $zip_count zip file(s) in $input_directory"

if [ -f "$LOCK_FILE" ]; then
    lock_age=$(( $(date +%s) - $(date +%s -r "$LOCK_FILE") ))

    if [ "$lock_age" -lt "$MAX_AGE" ]; then
        echo "Error: Script is already running (lock file: ${LOCK_FILE})" >&2
        exit 1
    else
        echo "Lock file is older than 1 hour, removing and continuing..."
        rm -f "$LOCK_FILE"
    fi
fi

# Log to file
exec > >(tee $process_directory/run.log) 2>&1

# Create lock file
echo $$ > "$LOCK_FILE"

# Remove lock file on exit (normal or error)
trap "rm -f '$LOCK_FILE'" EXIT

echo "- Script running with PID $$"

# Temporary debug
if true; then

# Run each stage on each collected zip file:
#
for zip_file in "$input_directory"/*;
do
  # Ignore non zip files
  [[ "${zip_file##*.}" != "zip" ]] && continue

  if [ -f "$zip_file" ]; then
    hostname=$(basename "$zip_file" .zip | cut -d_ -f2)

    # Same input_dir and output_dir seems to work. Makes it less complicated
    input_dir="${process_directory}/$(basename $zip_file .zip)"
    output_dir="${process_directory}/$(basename $zip_file .zip)"

    # Wine needs absolute Windows-style paths (Z: maps to /)
    win_input_dir="Z:$(realpath "$input_dir")"
    win_output_dir="Z:$(realpath "$output_dir")"

    mkdir -p "${output_dir}"

    echo ""
    echo "*********************************************************************"
    echo "*** Processing '$hostname'"
    echo "*********************************************************************"

    echo -e ""
    echo "*** Extracting  '$hostname' ***"
    run_cmd unzip -q -UU $zip_file -d $output_dir

    echo -e ""
    echo "*** Running Kape module EZParser ..."
    run_cmd wine bin/kape/kape.exe --msource "$win_input_dir" --mdest "$win_output_dir" --module \!EZParser

    echo -e ""
    echo "*** Running Kape module NirSoft_BrowsingHistoryView ..."
    run_cmd wine bin/kape/kape.exe --msource "${win_input_dir}/c" --mdest "$win_output_dir" --module NirSoft_BrowsingHistoryView

    echo -e ""
    echo "*** Parse Kape results ..."

    # Modules: "subdir:script:hostname_param"
    # subdir empty = always run with input_dir as -in
    MODULES=(
      "EventLogs:eventlogparser.ps1:-hostname"
      "ProgramExecution:programExecutionParser.ps1:-ComputerName"
      "FileFolderAccess:filefolderAccess.ps1:-ComputerName"
      "FileSystem:filesystem.ps1:-ComputerName"
      "BrowsingHistory:Browsinghistory.ps1:-ComputerName"
      "Registry:registryparser.ps1:-ComputerName"
      ":ConsoleHost.ps1:-ComputerName"
      ":DefenderLogs.ps1:-ComputerName"
    )

    for module in "${MODULES[@]}"; do
      IFS=':' read -r subdir script host_param <<< "$module"

      if [ -n "$subdir" ]; then
        mod_input="${win_input_dir}/${subdir}"
        [ ! -d "${input_dir}/${subdir}" ] && continue
      else
        mod_input="${win_input_dir}"
      fi

      if [ ! -f "$PARSE_MODULES_DIR/${script}" ]; then
        echo "WARNING: Module script not found: $PARSE_MODULES_DIR/${script}, skipping" >&2
        ERRORS=$((ERRORS + 1))
        continue
      fi

      echo -e ""
      echo "*** Parsing using module: ${script} ..."
      run_cmd wine /root/.wine/drive_c/pwsh/pwsh.exe -noni -File "$PARSE_MODULES_DIR/${script}" -in "${mod_input}" -outputdir "$win_output_dir" ${host_param} "$hostname"
    done

  fi
done

echo -e ""
echo "*** Merging CSV files ..."
run_cmd bin/merge_csv.py --process-dir $process_directory

echo -e ""
echo "*** Building timeline ..."
run_cmd bin/build_timeline.py --process-dir $process_directory

echo -e ""
echo "*** Building IP lists ..."
run_cmd bin/build_ip_lists.py --process-dir $process_directory

echo -e ""
echo "*** Collecting relevant data and copy to $output_directory/zip"

# Temporary debug
fi
#

mkdir -p ${process_directory}/zip

for zip_file in "$input_directory"/*;
do
  # Ignore non zip files
  [[ "${zip_file##*.}" != "zip" ]] && continue

  hostname=$(basename "$zip_file" .zip | cut -d_ -f2)

  echo "- Compressing ${process_directory}/$(basename $zip_file .zip)"/*.csv to ${hostname}.zip
  run_cmd zip ${process_directory}/zip/${hostname}.zip "${process_directory}/$(basename $zip_file .zip)"/*.csv -j
done

echo -e ""
echo "- Organizing files"

cp -v templates/README.txt $process_directory/zip
cp -v $process_directory/Timeline.csv $process_directory/zip
cp -v $process_directory/run.log $process_directory/zip
cp -v $process_directory/Timeline.xlsx $process_directory/zip
cp -v $process_directory/ip-addresses-timestamp.csv $process_directory/zip
mkdir -p $process_directory/zip/merged_csv
cp -v $process_directory/*.csv $process_directory/zip/merged_csv


echo -e ""
echo "- Compressing ${output_directory}/${title}.zip"
run_cmd zip ${output_directory}/${title}.zip $process_directory/zip/* -j

echo -e ""
echo "- Clearing input_directory ..."
rm -rf $input_directory/*

echo -e ""
echo "- Clearing $process_directory ..."
rm -rf $process_directory/*

echo ""
if [ $ERRORS -gt 0 ]; then
    echo "*** COMPLETED WITH $ERRORS ERROR(S) ***"
    exit 1
else
    echo "*** COMPLETED SUCCESSFULLY ***"
    exit 0
fi
