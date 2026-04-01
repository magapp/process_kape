param (
    [string]$in = "",
    [string]$outputdir = "",
    [string]$ComputerName ="" 
)
$BrowsingHistory = @()
$files =$in + "\"+  (Get-ChildItem ($in + "\") |Where-Object{$_.Name -match "BrowsingHistory.csv"}).Name  
foreach ($history in $files){
    $importedHistory = import-csv $history
    foreach ($event in $importedHistory){
        $tmp = [PSCustomObject]@{
            Timestamp = $event.'Visit Time'
            Event = "Browsing History"
            EventDescription = $event.'url'
            User = $event.'user profile'
            Hostname = $ComputerName 
            IPAddress = ""
            RemoteHostname = ""
            RemoteIP = ""
            Source = $event.'Web Browser'
            Comment = if($event.'Visited From'){"Visitem From: " + $event.'Visited From'}
        }
        $BrowsingHistory += $tmp
    }
    
}
$BrowsingHistory | Get-Unique -Asstring| Export-csv $outputdir/Browsinghistory.csv -Append 