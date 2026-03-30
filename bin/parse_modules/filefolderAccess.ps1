##########################
#  Output arrays         #
##########################

param (
    [string]$in = "",
    [string]$outputdir = "",
    [string]$ComputerName ="" 
)
$Shellbags = @()
$linkfiles = @()

##############################
#    Parsing Shellbags       #
##############################
Write-Host "Parsing shellbags..."
$shellbagsFiles =(Get-ChildItem ($in + "\") |Where-Object {$_.Name -match "NTUSER.csv|UsrClass.csv"})
foreach ($shellbagfile in $shellbagsFiles){
    $tmpfilename = $in + "\"+ $shellbagfile.Name
    #Write-Host $tmpfilename
    $imported = import-csv $tmpfilename 
    #write-host $shellbagfile
    $username = $shellbagfile.BaseName.Split("_")[0]
    #write-host "Parsing shellbags for the user: "$username 
    foreach ($event in $imported){
        #$event
        $tmp = [PSCustomObject]@{
            Timestamp = $event.LastWriteTime
            Event = "Shellbags"
            EventDescription = $event.AbsolutePath
            User = $username
            Hostname = $ComputerName 
            IPAddress = ""
            RemoteHostname = ""
            RemoteIP = ""
            Source = "Registry"
            Comment = if ($event.FirstInteracted) { "First Interacted: " + $event.FirstInteracted } else { ""}
        }
        $Shellbags += $tmp
    }
}
$Shellbags| Export-csv $outputdir/Shellbags.csv -Append
Remove-Variable -Name Shellbags

##############################
#    Parsing Link files      #
##############################
Write-Host "Parsing link files..."
$files = (Get-ChildItem ($in + "\") |Where-Object{$_.Name -match "LECMD_Output.csv"}).Name  
foreach ($linkfile in $files){
    $imported = import-csv ($in + "\"+  $linkfile)
    # We don't want other manually created link files. 
    foreach ($event in $imported){
        if ($event.sourcefile -like "*Users*" -and $event.LocalPath){
            $FirstFileAccess = [PSCustomObject]@{
                Timestamp = $event.SourceCreated
                Event = "Link file"
                EventDescription = $event.LocalPath
                User = $event.sourcefile.split("\Users\")[-1].split("\")[0]
                Hostname = $ComputerName 
                IPAddress = ""
                RemoteHostname = ""
                RemoteIP = ""
                Source = "Filesystem"
                Comment = "SourceFile: " + $event.sourcefile
            }
            $LastFileAccess = [PSCustomObject]@{
                Timestamp = $event.SourceModified
                Event = "Link file"
                EventDescription = $event.LocalPath
                User = $event.sourcefile.split("\Users\")[-1].split("\")[0]
                Hostname = $ComputerName 
                IPAddress = ""
                RemoteHostname = ""
                RemoteIP = ""
                Source = "Filesystem"
                Comment = "SourceFile: " + $event.sourcefile
            }
        $linkfiles += $FirstFileAccess
        $linkfiles += $LastFileAccess
     }

    }
   

}

$linkfiles | Get-Unique -Asstring | Export-csv $outputdir/linkfiles.csv -Append
Remove-Variable -Name linkfiles



Write-Host "Done!"