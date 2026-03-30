##########################
#  Output arrays         #
##########################

param (
    [string]$in = "",
    [string]$outputdir = "",
    [string]$ComputerName ="" 
)
$ProgramExecution = @()


##########################
#       Amcache          #
##########################
Write-Host "Parsing Amcache..."
$Unassociated = (Get-ChildItem ($in + "\") |Where-Object {$_.Name -match "Amcache_UnassociatedFileEntries.csv"}).Name # Searching for zimmerman output which should have been generated
#$Unassociated | ogv 

foreach ($event in $Unassociated){
    $amcache = import-csv ($in + "\"+ $event)
    foreach ($event in $amcache){
        #write-host $event
        if($event.IsOsComponent -eq "false" -and $event.Fullpath){
            $tmp = [PSCustomObject]@{
                Timestamp = $event.FileKeyLastWriteTimestamp
                Event = "Amcache"
                EventDescription = $event.Fullpath
                User = ""
                Hostname = $ComputerName 
                IPAddress = ""
                RemoteHostname = ""
                RemoteIP = ""
                Source = "Amcache.hve"
                Comment ="SHA1=" + $event.SHA1
            }
            #$tmp
            $ProgramExecution += $tmp
        }
    }
}
##########################
#    AppCompatCache      #
##########################
Write-Host "Parsing AppCompatCache..."
#20241213094421_Windows10Creators_SYSTEM_AppCompatCache.csv

$Location = (Get-ChildItem ($in + "\") |Where-Object {$_.Name -match "AppCompatCache.csv"}) # Searching for zimmerman output which should have been generated

#write-host $location
#$Location | ogv
foreach ($logfile in $Location){
    $tmpfilename = $in + "\"+ $logfile.Name
    $AppCompatCacheFile = import-csv $tmpfilename
    #write-host "Logfile" $logfile
    foreach ($event in $AppCompatCacheFile){
        if($event.LastModifiedTimeUTC){
            $tmp = [PSCustomObject]@{
                Timestamp = $event.LastModifiedTimeUTC
                Event = "AppCompatCache"
                EventDescription = $event.Path
                User = ""
                Hostname = $ComputerName 
                IPAddress = ""
                RemoteHostname = ""
                RemoteIP = ""
                Source = "Registry"
                Comment = ""
            }
        }
        $ProgramExecution += $tmp # There are some events that doesn't have any information. 

    }

}



$ProgramExecution | Get-Unique -Asstring | Export-csv $outputdir/ProgramExecution.csv -Append