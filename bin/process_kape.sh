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
KAPE="$WINE bin/kape.exe"

PARSE_MODULES_DIR="bin/parse_modules"

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
                                                                                                                                                                                        
echo "***"
echo "*** Step 1 - Unzip all collected Kape files ***"
echo "***"

for file in "$input_directory"/*; 
do

    # Ignore non zip files
    [[ "${file##*.}" != "zip" ]] && continue

    if [ -f "$file" ]; then
        # New directory will be created for each Kape .zip -> <process_directory>/<server>
	
        extract_dir="$process_directory/$(basename $file .zip)_extracted"

	# If extract_dir already exists, skip (this is if you run process_kape.sh several times for debug purposes)
	[ -d "$extract_dir" ] && continue

        echo "- Extracting $file to $extract_dir ..."

        mkdir -p $extract_dir
        unzip -q $file -d $extract_dir
    fi
done                                   
                                                                                                                                                                                        
echo "***"
echo "*** Step 2 - Kape processing artifacts ***"
echo "***"

for file in "$input_directory"/*; 
do
    [[ "${file##*.}" != "zip" ]] && continue

    if [ -f "$file" ]; then
        extract_dir="$process_directory/$(basename $file .zip)_extracted"
        parsed_dir="$process_directory/$(basename $file .zip)_parsed"

	# If _parsed dir already exists, skip (this is if you run process_kape.sh several times for debug purposes)
	[ -d "$parsed_dir" ] && continue

        echo "Parsing $extract_dir to $parsed_dir ..."

        mkdir -p $parsed_dir

        # Starting parsing of artifacts using Kape.
        echo "- Starting Kape Parsing... "
        $KAPE --msource $extract_dir --mdest $parsed_dir --module \!EZParser
        echo "- Starting additional Kape processing for persistance & web browser history ... "

        $location = $unzip_destionation +"/c/"

        # $KAPE --msource ${extract_dir}/c/ --mdest $parsed_dir --module NirSoft_BrowsingHistoryView,RECmd_RegistryASEPs,RECmd_SoftwareASEP
        $KAPE --msource ${extract_dir}/c/ --mdest $parsed_dir --module NirSoft_BrowsingHistoryView

        echo "- Kape parse done"
    fi
done

echo "***"
echo "*** Step 3 - Parse parsed Kape results ***"
echo "***"

for file in "$process_directory"/*_parsed; 
do
    if [ -d "$file" ]; then

        # Get hostname from directory name:
	hostname=$(basename "$file" | cut -d_ -f2)

        output_dir="$process_directory/$(basename $file .zip)_output"
        mkdir -p $output_dir

        echo "- Launching module: eventlogparser.ps1 ..."
        $POWERSHELL "$PARSE_MODULES_DIR\eventlogparser.ps1 -in ${file}\EventLogs -outputdir $output_dir -hostname $hostname"

        echo "- Launching module: ProgramExecutionparser ..."
        $POWERSHELL "$PARSE_MODULES_DIR\ProgramExecutionparser.ps1 -in ${file}\ProgramExecution -outputdir $output_dir -ComputerName $hostname"

        echo "- Launching module: filefolderAccess ..."
        #$folderpath = $result.FullName + "\FileFolderAccess"
        $POWERSHELL "$PARSE_MODULES_DIR\filefolderAccess.ps1 -in ${file}\FileFolderAccess -outputdir $output_dir -ComputerName $hostname"
    
        echo "- Launching module: filesystem ..."
        $POWERSHELL "$PARSE_MODULES_DIR\filesystem.ps1 -in ${file}\FileSystem -outputdir $output_dir -ComputerName $hostname"
    
        echo "- Launching module: Browsinghistory ..."
        $POWERSHELL "$PARSE_MODULES_DIR\Browsinghistory.ps1 -in ${file}/BrowsingHistory -outputdir $output_dir -ComputerName $hostname"
    
        echo "- Launching module: Registry ..."
        $POWERSHELL "$PARSE_MODULES_DIR\RegistryParser.ps1 -in ${file}/Registry -outputdir $output_dir -ComputerName $hostname"
    fi
done

echo "***"
echo "*** Step 4 - Parse raw Kape results ***"
echo "***"

for file in "$process_directory"/*_extracted; 
do
    if [ -d "$file" ]; then

        # Get hostname from directory name:
	hostname=$(basename "$file" | cut -d_ -f2)

	output_dir="$process_directory/$(basename ${file/_extracted/_parsed})_output"
        mkdir -p $output_dir

        echo "- Launching module: ConsoleHost ..."
        $POWERSHELL "$PARSE_MODULES_DIR\ConsoleHost.ps1 -in ${file} -outputdir $output_dir -ComputerName $hostname"

        echo "- Launching module: DefenderLogs ..."
        $POWERSHELL "$PARSE_MODULES_DIR\ConsoleHost.ps1 -in ${file} -outputdir $output_dir -ComputerName $hostname"
    fi

done

echo "***"
echo "*** Step 5 - Create timeline"
echo "***"


https://github.com/Barvemo/timeline/blob/7a73ebdb1d36a42a9af7282ad8fda44e6c0adf13/timeline.exe
exit 1

#echo "- Clearing input_directory ..."
#rm -rf $input_directory/*

#echo "- Clearing $process_directory ..."
#rm -rf $process_directory/*

