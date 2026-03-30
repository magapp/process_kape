##########################
#  input parameters      #
##########################
param (
    [string]$in = "",
    [string]$outputdir = "",
    [string]$ComputerName ="" 
)

$persistence = @()
##########################
#  Initializing          #
##########################

Write-Host "Parsing Registry..."
$ASEPFile =($in + "\") + (Get-ChildItem ($in + "\") |Where-Object{$_.Name -match "Batch_RegistryASEPs_Output.csv"}).Name
write-host "Loading file: "$ASEPFile

$ASEP = import-csv $ASEPFile 

foreach ($event in $ASEP){
    $tmp = [PSCustomObject]@{
        Timestamp = $event.LastWriteTimestamp
        Event = "Persistance"
        EventDescription = $event.Description + " - " + $event.Valuedata
        User = ""
        Hostname = $ComputerName 
        IPAddress = ""
        RemoteHostname = ""
        RemoteIP = ""
        Source = "Registry"
        Comment = $event.HiveType + " - " + $event.KeyPath
    }
    $persistence += $tmp 
}


$persistence | Export-csv $outputdir/persistence.csv -Append
Remove-Variable -Name persistence