#!/bin/bash                                                                                                                                                                           
                
input_directory="$1"                                                                                                                                                                  
process_directory="$2"                                                                                                                                                                  
output_directory="$3"                                                                                                                                                                  

KAPE="wine bin/kape.exe"

LOCK_FILE="${input_directory}/run.lock"
MAX_AGE=36000  # 10 hour in seconds

if ! which unzip &> /dev/null; then
    echo "Error: 'unzip' is not installed or not in PATH" >&2
    exit 1
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

echo "- Clearing $process_directory ..."
rm -rf $process_directory/*

# Log to file
exec > >(tee $process_directory/run.log) 2>&1

# Create lock file
echo $$ > "$LOCK_FILE"

# Remove lock file on exit (normal or error)
trap "rm -f '$LOCK_FILE'" EXIT

echo "- Script running with PID $$"
                                                                                                                                                                                        
echo "*** Step 1 - Unzip all collected Kape files ***"
for file in "$input_directory"/*; 
do
    if [ -f "$file" ]; then
        extract_dir="$process_directory/$(basename $file .zip)"

        echo "- Extracting $file to $extract_dir ..."

        mkdir -p $extract_dir
        unzip -q $file -d $extract_dir
    fi
done                                   
                                                                                                                                                                                        
echo "*** Step 2 - Kape processing artifacts ***"

for file in "$input_directory"/*; 
do
    if [ -f "$file" ]; then
        extract_dir="$process_directory/$(basename $file .zip)"
        parsed_dir="$process_directory/$(basename $file .zip)_parsed"

        echo "Parsing $extract_dir to $parsed_dir ..."

        mkdir -p $parsed_dir

        # Starting parsing of artifacts using Kape.
        echo "- Starting Kape Parsing... "
        $KAPE --msource $extract_dir --mdest $parsed_dir --module !EZParser
        echo "- Starting additional Kape processing for persistance & web browser history ... "

        $location = $unzip_destionation +"/c/"

        # $KAPE --msource ${extract_dir}/c/ --mdest $parsed_dir --module NirSoft_BrowsingHistoryView,RECmd_RegistryASEPs,RECmd_SoftwareASEP
        $KAPE --msource ${extract_dir}/c/ --mdest $parsed_dir --module NirSoft_BrowsingHistoryView

        echo "- Kape parse done"
    fi
done

echo "*** Step 3 - Parse parsed Kape results ***"

foreach ($result in $KapeResults){
    # Parsing Eventlogs

    Write-Host "> Parsing Parsed Kape resuts for for " $result.BaseName -ForegroundColor Green

    if ($result.BaseName -match "T\d{6}_(.+)") {   #AI generated, but seems to work :)
        $hostname = $matches[1]
    }else{
        $hostname = $result.BaseName
    }

    Write-Host ">> Launching module: eventlogparser.ps1"  -ForegroundColor Gray
    $folderpath = $result.FullName + "\Eventlogs"
    .\modules\eventlogparser.ps1 -in $folderpath -outputdir $ParsedFolder -hostname $hostname



#$KAPE --msource input_directory --mdest output_directory --module !EZParser



# For each zip-file
#$KAPE --msource input_directory/c/ --mdest output_directory --module NirSoft_BrowsingHistoryView,RECmd_RegistryASEPs,RECmd_SoftwareASEP
#$KAPE --msource input_directory/c/ --mdest output_directory --module NirSoft_BrowsingHistoryView

echo "- Clearing input_directory ..."
rm -rf $input_directory/*
