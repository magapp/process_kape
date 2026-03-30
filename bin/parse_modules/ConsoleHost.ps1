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
$ConsoleHost = @()
$files =(Get-ChildItem ($in + "\") -Recurse | Where-Object{$_.Name -match "ConsoleHost_history.txt"})  

foreach ($file in $files){
    #Write-Host $files -ForegroundColor Blue
    $history = Get-Content $file

    $segments = $file -split '\\'
    $userIndex = [Array]::IndexOf($segments, 'Users') + 1
    $owner = $segments[$userIndex]

    #Write-Host "Owner: $owner" -ForegroundColor Blue
    foreach ($command in $history) {
        $ConsoleHost += [PSCustomObject]@{
            Command     = $command
            Username    = $owner
            Computer    = $ComputerName
            Source      = $file
        }
    }
}
$ConsoleHost | Get-Unique -Asstring| Export-csv $outputdir/ConsoleHost_history.csv -Append 