
##########################
#  input parameters      #
##########################
param (
    [string]$in = "",
    [string]$outputdir = "",
    [string]$ComputerName ="" 
)



Write-Host "Parsing Registry..."
$Registryoutputfile =(Get-ChildItem ($in + "\") |Where-Object{$_.Name -match "Kroll_Batch_Output.csv"}).Name
foreach ($event in $Registryoutputfile){
    ##########################
    #  Initializing          #
    ##########################
    $tmp = ($in + "\") + $event
    write-host "Loading file: "$tmp

    $Registry = [System.Collections.Generic.List[string]]::new()

    $header = "Timestamp,Event,EventDescription,User,Hostname,IPAddress,RemoteHostname,RemoteIP,Source,Comment"
    $Registry.Add($header)

    $streamReader = [System.IO.StreamReader]::new($tmp)  # Reading the csv file line by line. way faster than import-csv. 
    $counter = 0



    # Create a StreamWriter to append to the file
    if (Test-Path $outputdir/Registry.csv){
        $streamWriter = [System.IO.StreamWriter]::new("$outputdir/Registry.csv", $True, [System.Text.Encoding]::UTF8)

    }Else{
        $streamWriter = [System.IO.StreamWriter]::new("$outputdir/Registry.csv", $True, [System.Text.Encoding]::UTF8)
        $header = "Timestamp,Event,EventDescription,User,Hostname,IPAddress,RemoteHostname,RemoteIP,Source,Comment"
        $streamWriter.WriteLine($header)
    }


    ##########################
    #  Parsing the file      #
    ##########################

    # This is the header from the kape output. 
    $Header = 'HivePath','HiveType','Description','Category','KeyPath',
            'ValueName','ValueType','ValueData','ValueData2','ValueData3',
            'Comment','Recursive','Deleted','LastWriteTimestamp','PluginDetailFile'


    try {
        while ($null -ne ($line = $streamReader.ReadLine())) {
            if ($line -like "HivePath,HiveType,*") {   
                continue
            }
            $counter += 1
            $fields = $line | ConvertFrom-Csv -header $Header
            if($fields.LastWriteTimestamp){
                $RegistryEvent = $fields.LastWriteTimestamp +","+ "RegistryLastWrite" + "," + $fields.KeyPath + ",," + $ComputerName +  ",,,,Registry," + $fields.comment 
                $streamWriter.WriteLine($RegistryEvent)
            }
        }
    } finally {
        $streamReader.Close()
        $streamWriter.Close()
    }
}

Write-Host "Total lines processed: $counter"