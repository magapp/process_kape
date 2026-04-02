#!/bin/bash                                                                                                                                                                           
                
input_directory="$1"                                                                                                                                                                  
process_directory="$2"                                                                                                                                                                  
output_directory="$3"                                                                                                                                                                  
title="$4"

#if [ `whoami` == "root" ]; then
    #WINE="wine"
#else
    #WINE="sudo wine"
#fi
WINE="sudo wine"

POWERSHELL="$WINE powershell -noni -c"
KAPE="$WINE bin/kape/kape.exe"

PARSE_MODULES_DIR="bin/kape/parse_modules"

LOCK_FILE="${input_directory}/run.lock"
MAX_AGE=36000  # 10 hour in seconds

if ! which unzip &> /dev/null; then
    echo "Error: 'unzip' is not installed or not in PATH" >&2
    exit 1
fi

if [ ! -d "$PARSE_MODULES_DIR" ]; then
	echo "Directory $PARSE_MODULES_DIR not found, so I cant find parse modules"
        exit 1;
fi
                      
# input_directory is typical "downloaded"
# process_directory is a temporary dir, where unzip and processing will occur
# output_directory is where downloadable result will be 
# title is a name for the project
USAGE="Usage: run.sh <input directory> <process_directory> <output directory> <title>"
if [ ! -d "$input_directory" ]; then
	echo $USAGE
        exit 1;
fi

if [ ! -d "$process_directory" ]; then
	echo $USAGE
        exit 1;
fi

if [ ! -d "$output_directory" ]; then
	echo $USAGE
        exit 1;
fi

if [ -z "$title" ]; then
	echo $USAGE
        exit 1;
fi

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

    mkdir -p "${output_dir}"

    echo ""
    echo "*********************************************************************"
    echo "*** Processing '$hostname'"
    echo "*********************************************************************"
    
    echo ""
    echo "*** Extracting  '$hostname' ***"
    unzip -q $zip_file -d $output_dir

    echo ""
    echo "*** Parsing Kape artifact '$hostname' ***"
    $KAPE --msource $input_dir --mdest $output_dir --module \!EZParser

    echo "- Parsing additional Kape processing for persistance and web browser history ..."
    # $KAPE --msource ${input_dir}/c/ --mdest $output_dir --module NirSoft_BrowsingHistoryView,RECmd_RegistryASEPs,RECmd_SoftwareASEP
    $KAPE --msource ${input_dir}/c/ --mdest $output_dir --module NirSoft_BrowsingHistoryView

    echo ""
    echo "*** Parse parsed Kape results '$hostname' ..."

    if [ -d ${input_dir}/EventLogs  ]; then
      echo "- Launching module: eventlogparser.ps1 ..."
      $POWERSHELL "$PARSE_MODULES_DIR/eventlogparser.ps1 -in ${input_dir}\\EventLogs -outputdir $output_dir -hostname $hostname"
    fi
  
    if [ -d ${input_dir}/ProgramExecution  ]; then
      echo "- Launching module: ProgramExecutionparser ..."
      $POWERSHELL "$PARSE_MODULES_DIR/ProgramExecutionparser.ps1 -in ${input_dir}\\ProgramExecution -outputdir $output_dir -ComputerName $hostname"
    fi
  
    if [ -d ${input_dir}/FileFolderAccess  ]; then
      echo "- Launching module: filefolderAccess ..."
      $POWERSHELL "$PARSE_MODULES_DIR/filefolderAccess.ps1 -in ${input_dir}\\FileFolderAccess -outputdir $output_dir -ComputerName $hostname"
    fi
  
    if [ -d ${input_dir}/FileSystem  ]; then
      echo "- Launching module: filesystem ..."
      $POWERSHELL "$PARSE_MODULES_DIR/filesystem.ps1 -in ${input_dir}\\FileSystem -outputdir $output_dir -ComputerName $hostname"
    fi
  
    if [ -d ${input_dir}/BrowsingHistory  ]; then
      echo "- Launching module: Browsinghistory ..."
      $POWERSHELL "$PARSE_MODULES_DIR/Browsinghistory.ps1 -in ${input_dir}\\BrowsingHistory -outputdir $output_dir -ComputerName $hostname"
    fi
  
    if [ -d ${input_dir}/Registry  ]; then
      echo "- Launching module: Registry ..."
      $POWERSHELL "$PARSE_MODULES_DIR/RegistryParser.ps1 -in ${input_dir}\\Registry -outputdir $output_dir -ComputerName $hostname"
    fi

    echo ""
    echo "*** Parse raw Kape results '$hostname' ..."

    echo "- Launching module: ConsoleHost ..."
    $POWERSHELL "$PARSE_MODULES_DIR/ConsoleHost.ps1 -in ${input_dir} -outputdir $output_dir -ComputerName $hostname"
  
    echo "- Launching module: DefenderLogs ..."
    $POWERSHELL "$PARSE_MODULES_DIR/DefenderLogs.ps1 -in ${input_dir} -outputdir $output_dir -ComputerName $hostname"
    echo MAGNUS DEBUG $POWERSHELL "$PARSE_MODULES_DIR/DefenderLogs.ps1 -in ${input_dir} -outputdir $output_dir -ComputerName $hostname"

  fi
done

echo ""
echo "*** Merging CSV files ..."
echo MAGNUS DEBUG bin/merge_csv.py --process-dir $process_directory
bin/merge_csv.py --process-dir $process_directory

echo ""
echo "*** Building timeline ..."
bin/build_timeline.py --process-dir $process_directory

echo ""
echo "*** Building IP lists ..."
bin/build_ip_lists.py --process-dir $process_directory

echo ""
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
  echo MAGNUS DEBUG zip ${process_directory}/${hostname}.zip "${process_directory}/zip/$(basename $zip_file .zip)"/*.csv -j
  zip ${process_directory}/zip/${hostname}.zip "${process_directory}/$(basename $zip_file .zip)"/*.csv -j
done

echo "- Organizing files"

cp -v templates/README.txt $process_directory/zip
cp -v $process_directory/Timeline.csv $process_directory/zip
cp -v $process_directory/Timeline.xlsx $process_directory/zip
cp -v $process_directory/ip-addresses-timestamp.csv $process_directory/zip
mkdir -p $process_directory/zip/merged_csv
cp -v $process_directory/*.csv $process_directory/zip/merged_csv


echo "- Compressing ${output_directory}/${title}.zip"
echo MAGNUS DEBUG zip ${output_directory}/${title}.zip $process_directory/zip/* -j
zip ${output_directory}/${title}.zip $process_directory/zip/* -j
    
echo ""
echo "- Clearing input_directory ..."
sudo rm -rf $input_directory/*

echo ""
echo "- Clearing $process_directory ..."
sudo rm -rf $process_directory/*

exit 0
