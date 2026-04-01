#$eventlog = import-csv "D:\Dystopia\IF-DC\eventlog\parsed\20241016121033_EvtxECmd_Output.csv"

<#
The tool parses eventlog to a readable CSV format using EvtxECmd. Run run it, place the EvtxECmd folder in the same direction 

EvtxECmd can be downloaded from: 
https://ericzimmerman.github.io/#!index.md


Example:


#>


##########################
#  Output arrays         #
##########################

param (
    [string]$in = "",
    [string]$outputdir = "",
    [string]$hostname ="" 
)

#Write-Host $in
#write-host "Parsing file: "$in
#$timeline = @()
$login = @()
$Services = @()
$scheduledTasks = @()
$rdp_server = @()
$rdp_client = @()
$account_creation = @()
$antivirus = @()
$Evasion = @()
$sysmon = @()
$process_start = @()

##########################
# Parsing input          #
##########################
$EvtOutputs = (Get-ChildItem ($in + "\") |Where-Object {$_.Name -match "EvtxECmd_output.csv"}).Name # Searching for zimmerman output which should have been generated

foreach ($event in $EvtOutputs){
    write-host ("parsing " + $event + "")
    $tmp =  $in + "\"+ $event
    $streamReader = [System.IO.StreamReader] $tmp # Reading the csv file line by line. way faster than import-csv. 'ä''
    $parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($streamReader)

    $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
    $parser.SetDelimiters(",")
    $parser.HasFieldsEnclosedInQuotes = $true

    # Read the header
    $header = $parser.ReadFields()

 #   while ($line = $streamReader.ReadLine()) {
 #       # Skip the header line
 #       if ($streamReader.BaseStream.Position -eq 0) {
 #           continue
 #       }
 
        # Process the line here, splitting by comma for CSV fields
       # $fields = $line.Split(',')


    while (!$parser.EndOfData) {
        $fields = $parser.ReadFields()
        $timestamp = $fields[2].split(".")[0]
        $eventid = $fields[3]
        $computer = $fields[9]
        $channel = $fields[6]
        $PayloadData6 = $fields[20]
        $PayloadData5 = $fields[19]
        $PayloadData4 = $fields[18]
        $PayloadData3 = $fields[17]
        $PayloadData2 = $fields[16]
        $PayloadData1 = $fields[15]
       # $payloaddata1 = $fields[15] #NOTUSED
        ###############
        #    SYSMON  #
        ###############
        # https://learn.microsoft.com/sv-se/sysinternals/downloads/sysmon 
        if($channel -match "sysmon"){
            if($eventid -eq "1"){ # Process Creation
                $tmp = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Event = "Process Creation"
                    EventDescription = $PayloadData6 
                    User = $fields[13]
                    Hostname = $fields[9] #Computer 
                    IPAddress = ""
                    RemoteHostname = $RemoteHostname
                    #RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
                    RemoteIP = ""
                    Source = $fields[6] #channel
                    Comment = $fields[26]
                }
                $sysmon += $tmp
            }


            if($eventid -eq "11"){ # File Creation
                $tmp = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Event = "FileCreated"
                    EventDescription = $PayloadData4 
                    User = $fields[13]
                    Hostname = $fields[9] #Computer 
                    IPAddress = ""
                    RemoteHostname = $RemoteHostname
                    #RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
                    RemoteIP = ""
                    Source = $fields[6] #channel
                    Comment = $fields[26] 
                }
                $sysmon += $tmp
            }

            if($eventid -eq "12"){ # File Creation
                $tmp = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Event = "Registry Event"
                    EventDescription = ($PayloadData4+" " + $PayloadData3 + " " + $PayloadData5)
                    User = $fields[13]
                    Hostname = $fields[9] #Computer 
                    IPAddress = ""
                    RemoteHostname = $RemoteHostname
                    #RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
                    RemoteIP = ""
                    Source = $fields[6] #channel
                    Comment = $fields[26] 
                }
                $sysmon += $tmp
            }


            if($eventid -eq "3"){ # Network Connection
                if(($PayloadData3 -replace "SourceHostname: ", "")  -eq $fields[9]){ #outgoing connection 
                    $tmp = [PSCustomObject]@{
                        Timestamp = $timestamp
                        Event = "Outgoing Network Connection"
                        EventDescription = ($PayloadData2  + "   " + $PayloadData6 + "   " + $PayloadData5)
                        User = $fields[13]
                        Hostname = $PayloadData3 -replace "SourceHostname:", ""  
                        IPAddress = $PayloadData4 -replace "SourceIp:", "" #Source IP
                        RemoteHostname = $PayloadData5 -replace "DestinationHostname:", ""
                        RemoteIP = $PayloadData6 -replace "DestinationIp:", "" # RemoteHost
                    # RemoteIP = $PayloadData6
                        Source = $fields[6] #channel
                        Comment = $fields[26] 
                    }
                }else{
                    $tmp = [PSCustomObject]@{
                        Timestamp = $timestamp
                        Event = "Incoming Network Connection"
                        EventDescription = ($PayloadData2  + "  " + $PayloadData4  + "  "+ $PayloadData3)
                        User = $fields[13]
                        Hostname =  $PayloadData5 -replace "DestinationHostname:", ""
                        IPAddress = $PayloadData6 -replace "DestinationIp:", "" # RemoteHost 
                        RemoteHostname =$PayloadData3 -replace "SourceHostname:", ""  
                        RemoteIP = $PayloadData4 -replace "SourceIp:", "" #Source IP
                    # RemoteIP = $PayloadData6
                        Source = $fields[6] #channel
                        Comment = $fields[26] 
                    }

                }

                $sysmon += $tmp
            }
            if($eventid -eq "8"){ # Create Remote Thread 
                $tmp = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Event = "CreateRemoteThread"
                    EventDescription = ($PayloadData4  + "  "+ $PayloadData6g)
                    User = $fields[13]
                    Hostname =  $fields[9] #Computer 
                    IPAddress =  ""
                    RemoteHostname =""
                    RemoteIP = ""
                    # RemoteIP = $PayloadData6
                    Source = $fields[6] #channel
                    Comment = $fields[26] 
                }
                $sysmon += $tmp
            }
        }

        


        ##########################
        #    Eventlog Cleared    #
        ##########################
        if($eventid -eq "104" -or $eventid -eq "1102"){
            #write-host "test"
            #write-host $fields
            if($channel -match "security|system"){
                $tmp = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Event = "Eventlog Cleared"
                    EventDescription = ("eventid: " + $eventid + " " + $fields[12])
                    User = $fields[13]
                    Hostname = $fields[9] #Computer 
                    IPAddress = ""
                    RemoteHostname = $RemoteHostname
                    #RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
                    RemoteIP = ""
                    Source = $fields[6] #channel
                    Comment = $fields[15]
                }
                $Evasion += $tmp
            }
        }    

        ##########################
        #      Anvitivirus       #
        ##########################
        if($channel -match "Microsoft-Windows-Windows Defender/Operational"){
            if($eventid -match "5001|1006|1007|1008|1009|1010|1013|1015|1116|1117|1118"){
                $tmp = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Event = "Antivirus"
                    EventDescription = ("eventid: " + $eventid + " " + $fields[12])
                    User = ""
                    Hostname = $fields[9] #Computer 
                    IPAddress = ""
                    RemoteHostname = $RemoteHostname
                    #RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
                    RemoteIP = ""
                    Source = $fields[6] #channel
                    Comment = $fields[15]
                }
                $antivirus += $tmp
            }
        }

        ##########################
        #      Sign-ins          #
        ##########################
        if($eventid -eq "4624" -or $eventid -eq "4625"){
            #$fields
            $ip = ($fields[14].split('\ ')[1])
            $RemoteHostname = $fields[14].split('\ ')[0]
            $tmp = [PSCustomObject]@{
                Timestamp = $timestamp
                Event = $fields[12]
                EventDescription = ("eventid: " + $eventid + " " + $fields[16])
                User = $fields[15] -replace "target: ", "" #Payloaddata1
                Hostname = $fields[9] #Computer 
                IPAddress = ""
                RemoteHostname = $RemoteHostname
                #RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
                RemoteIP = $ip
                Source = $fields[6] #channel
                Comment = ""
            }
            $login += $tmp
        }
        ##########################
        #      RDP Server        #
        ##########################
        
        if($channel -match "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"){
            if($eventid -match "21|22|23|24|25"){
                #$fields
                $tmp = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Event = "RDP Server"
                    EventDescription = (($fields[12] -replace "Remote Desktop Services:", "") + "(" + $fields[15] + ")")
                    User = $fields[13]
                    Hostname = $fields[9] #Computer 
                    IPAddress = ""
                    RemoteHostname = ""
                    RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
                    Source = $fields[6] #channel
                    Comment = $fields[12]
                }
                $rdp_server += $tmp
            }
        }
        ##########################
        #      RDP Client        #
        ##########################
        if($channel -match "Microsoft-Windows-TerminalServices-RDPClient/Operational"){
            if($eventid -match "1024|1102"){
                # Check if the RemoteHost value contains an IP or a hostname. 
                try{
                    $ip = [ipaddress]($fields[15] -replace "Dest: ", "" -replace "address: ", "")
                    $RemoteHostname = ""
                }
                catch{
                    $ip = ""
                    $RemoteHostname = ($fields[15] -replace "Dest: ", "" -replace "address: ", "")
                }
                #$fields
                $tmp = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Event = "RDP Client"
                    EventDescription = (($fields[12]) + " (" + $fields[15] + ")")
                    User = $fields[13]
                    Hostname = $fields[9] #Computer 
                    IPAddress = ""
                    RemoteHostname = $RemoteHostname
                    RemoteIP = $ip
                    Source = $fields[6] #channel
                    Comment = ""
                }
                #$fields
                $rdp_client += $tmp
            }
        }

        ##########################
        #    Process Creation    #
        ##########################
        if($eventid -match "4688"){
            #$fields 
            $tmp = [PSCustomObject]@{
                Timestamp = $timestamp
                Event = "Process Creation"
                EventDescription = ($payloaddata1 + " | " + $PayloadData2)
                User = $fields[13]
                Hostname = $fields[9] #Computer 
                IPAddress = ""
                RemoteHostname = $RemoteHostname
                RemoteIP = $ip
                Source = $fields[6] #channel
                Comment = $fields[26]
            }
            $process_start += $tmp
        }

        ##########################
        #    Account Creation    #
        ##########################
        if($eventid -match "4720|4728"){
            #$fields 
            $tmp = [PSCustomObject]@{
                Timestamp = $timestamp
                Event = "Account Creation"
                EventDescription = (($fields[12]) + " (" + $fields[15] + ")")
                User = $fields[13]
                Hostname = $fields[9] #Computer 
                IPAddress = ""
                RemoteHostname = $RemoteHostname
                RemoteIP = $ip
                Source = $fields[6] #channel
                Comment = "WORK IN PROGRESS"
            }
            $account_creation += $tmp
        }


        ##########################
        # Service Installations  #
        ##########################
        if($eventid -eq "7045"){
        #$fields
        $tmp = [PSCustomObject]@{
            Timestamp = $timestamp
            Event = "Service Installation"
            EventDescription = (($fields[15] -replace "Name: ", "") +  " (eventid " + $eventid + ")")
            User = ""
            Hostname = $computer 
            IPAddress = ""
            RemoteHostname = ""
            RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
            Source = $channel
            Comment = $fields[21]
            }
        $services += $tmp
        }
        if($eventid -eq "4697"){
        #$fields
        $tmp = [PSCustomObject]@{
            Timestamp = $timestamp
            Event = "Service Installation"
            EventDescription = (($fields[15] -replace "Name: ", "") +  " (eventid " + $eventid + ")")
            User = ""
            Hostname = $computer 
            IPAddress = ""
            RemoteHostname = ""
            RemoteIP = $fields[14] -replace "\)", "" -replace "- \(", "" # RemoteHost
            Source = $channel
            Comment = $fields[17]
            }
        $services += $tmp
        }
        ##########################
        #   Scheduled Tasks      #
        ##########################
        if($eventid -eq "4698" -or ($eventid -eq "100" -AND $channel -match "Microsoft-Windows-TaskScheduler")){
        #$fields
        $tmp = [PSCustomObject]@{
            Timestamp = $timestamp
            Event = "Scheduled Task"
            EventDescription = (($fields[15] -replace "Name: ", "") +  " (eventid " + $eventid + ")")
            User = ""
            Hostname = $computer 
            IPAddress = ""
            RemoteHostname = ""
            RemoteIP = ""
            Source = $channel
            Comment =$fields[21]
            }
        $ScheduledTasks += $tmp
        }


    }
}
$streamReader.Close()
$parser.Close()

##########################
#   output generation    #
##########################
Write-Host "Parsing done.."
Write-Host "Generating output.."

$login | Get-Unique -Asstring | Export-csv $outputdir/logon.csv -Append
$Services | Get-Unique -Asstring | Export-csv $outputdir/services.csv -Append
$scheduledTasks | Get-Unique -Asstring | Export-csv $outputdir/scheduledtasks.csv -Append
$rdp_server | Get-Unique -Asstring  | Export-csv $outputdir/RDP_Server.csv -Append
$rdp_client  | Get-Unique -Asstring  | Export-csv $outputdir/RDP_Client.csv -Append
$account_creation | Get-Unique -Asstring  | Export-csv $outputdir/account_creation.csv -Append
$Evasion  | Get-Unique -Asstring | Export-csv $outputdir/evasion.csv -Append
$sysmon  | Get-Unique -Asstring | Export-csv $outputdir/sysmon.csv -Append
#$timeline = $login + $Services + $scheduledTasks + $rdp_server + $rdp_client + $account_creation 
#$timeline | Export-csv $outputdir/timeline.csv -Append
 
$antivirus | Get-Unique -Asstring |  Export-csv $outputdir/antivirus.csv  -Append
$process_start | Get-Unique -Asstring |  Export-csv $outputdir/process_start.csv  -Append

#Write-Host "Done!"
#>