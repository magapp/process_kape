param (
    [string]$in = "",
    [string]$outputdir = "",
    [string]$ComputerName ="" 
)


Write-Host ">> Searching for Consolehost history files in user directories. " -ForegroundColor Gray

<#

Finding all console host history files inside the user directories. For instance: 
C\Users\Administrator\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt

#>
$DefenderHistory = @()
$files =(Get-ChildItem ($in + "\") -Recurse | Where-Object{$_.Name -match "MPDetection"})  

foreach ($file in $files){
    #Write-Host $files -ForegroundColor Blue
    $history = Get-Content $file

    $segments = $file -split '\\'
    $userIndex = [Array]::IndexOf($segments, 'Users') + 1
    $owner = $segments[$userIndex]

    #Write-Host "Owner: $owner" -ForegroundColor Blue
    foreach ($command in $history) {
        $DefenderHistory += [PSCustomObject]@{
            Timestamp = $command.split("` ")[0].split("`.")[0] -Replace "T", " "
            Event = "Antivirus"
            EventDescription = $command -replace "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3} ", ""
            User = ""
            Hostname = $ComputerName 
            IPAddress = ""
            RemoteHostname = ""
            RemoteIP = ""
            Source = $file.Name
            Comment = "" 
        }
    }
}
$DefenderHistory | Get-Unique -Asstring| Export-csv $outputdir/antivirus.csv  -Append 
