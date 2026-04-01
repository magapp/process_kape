##########################
#  Output arrays         #
##########################

param (
    [string]$in = "",
    [string]$outputdir = "",
    [string]$ComputerName ="" 
)

Write-Host "Parsing MFT..."
$mftoutputfile =(Get-ChildItem ($in + "\") |Where-Object{$_.Name -match "MFT_Output.csv"}).Name

$MFT = [System.Collections.Generic.List[string]]::new()
$header = "Timestamp,Event,EventDescription,User,Hostname,IPAddress,RemoteHostname,RemoteIP,Source,Comment"
$MFT.Add($header)

foreach ($event in $mftoutputfile){
    $streamReader = [System.IO.StreamReader] (($in + "\") + $event)  # Reading the csv file line by line. way faster than import-csv. 
    $parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($streamReader)
    
    $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
    $parser.SetDelimiters(",")
    $parser.HasFieldsEnclosedInQuotes = $true

        # Read the header
    $header = $parser.ReadFields()
    #while ($line = $streamReader.ReadLine()) {
    while (!$parser.EndOfData) {
        # Process the line here, splitting by comma for CSV fields
        #$fields = $line.Split(',')
        $fields = $parser.ReadFields()
        if ($streamReader.BaseStream.Position -eq 0) {   
            continue
        }

        if($line -match '\"'){
            # This exception exists since no proper csv conversion is made. 
            # When a column includes " it can also include , which will break the output. 
            write-host '!! WARNING Found filename or path containing quatation marks \", skipping. ' 
            continue
        } 
        #$fields = $line.Split(',')
        #$Timestamp = $fields[6]
        $Created = $fields[19]
        $Modified = $fields[21]
        #$Access = $fields[25] #NOTUSED
        $FileName = $fields[6]
        $Folderpath = $fields[5]

        # Two events for each MFT entry are made, one for the last file modification and the file creation timestamp. 
        $csvCreated = $Created +","+ "FileCreated" + "," +  ($Folderpath + "\" + $FileName) + ",," + $ComputerName +  ",,,,MFT" 
        $csvModifed = $Modified +","+ "FileModified" + "," +  ($Folderpath + "\" + $FileName) + ",," + $ComputerName +  ",,,,MFT" 
        $MFT.Add($csvCreated)
        $MFT.Add($csvModifed)
    }
    $streamReader.Close() 
}

# Check if the MFT output file exists. 
if (Test-Path $outputdir/MFT.csv) {
    Write-Host "Appending results to existing output file. " 
    $MFT | Add-Content $outputdir/MFT.csv -Encoding utf8 

} else { 
    
    Write-Host "Creating new MFT output file, and adding CSV headers."  
    $MFT | Out-File -FilePath $outputdir/MFT.csv -Encoding utf8
}
