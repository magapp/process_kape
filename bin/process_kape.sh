#!/bin/bash                                                                                                                                                                           
                
input_directory="$1"                                                                                                                                                                  
process_directory="$2"                                                                                                                                                                  
output_directory="$3"                                                                                                                                                                  

if [ `whoami` == "root" ]; then
    WINE="wine"
else
    WINE="sudo wine"
fi

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
USAGE="Usage: run.sh <input directory> <process_directory> <output directory>"
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

    echo "*********************************************************************"
    echo "*** Processing '$hostname'"
    echo "*********************************************************************"
    
    # Temporary debug
    if false; then

    echo "*** Extracting  '$hostname' ***"
    unzip -q $zip_file -d $output_dir

    echo "*** Parsing Kape artifact '$hostname' ***"
    $KAPE --msource $input_dir --mdest $output_dir --module \!EZParser

    echo "- Parsing additional Kape processing for persistance and web browser history ..."
    # $KAPE --msource ${input_dir}/c/ --mdest $output_dir --module NirSoft_BrowsingHistoryView,RECmd_RegistryASEPs,RECmd_SoftwareASEP
    $KAPE --msource ${input_dir}/c/ --mdest $output_dir --module NirSoft_BrowsingHistoryView

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

    # Temporary debug
    fi
  
    echo "*** Parse raw Kape results '$hostname' ..."

    echo "- Launching module: ConsoleHost ..."
    $POWERSHELL "$PARSE_MODULES_DIR/ConsoleHost.ps1 -in ${input_dir} -outputdir $output_dir -ComputerName $hostname"
  
    echo "- Launching module: DefenderLogs ..."
    $POWERSHELL "$PARSE_MODULES_DIR/DefenderLogs.ps1 -in ${input_dir} -outputdir $output_dir -ComputerName $hostname"
    echo MAGNUS $POWERSHELL "$PARSE_MODULES_DIR/DefenderLogs.ps1 -in ${input_dir} -outputdir $output_dir -ComputerName $hostname"

  fi
done

echo "*** Merging CSV files ..."
bin/merge_csv.py --process-dir $output_dir

echo "*** Building timeline ..."
bin/build_timeline.py --process-dir $output_dir

echo "*** Building IP lists ..."
bin/build_ip_lists.py --process-dir $output_dir

echo "*** Collecting relevant data and copy to $output_directory ..."
cp -v templates/README.txt $output_dir
    
echo "- Clearing input_directory ..."
#rm -rf $input_directory/*

echo "- Clearing $process_directory ..."
#rm -rf $process_directory/*

exit 0
