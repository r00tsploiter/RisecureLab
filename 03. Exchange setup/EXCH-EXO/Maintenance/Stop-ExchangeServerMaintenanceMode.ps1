<#
.Synopsis
   Script to automatically take an Exchange 2013/2016/2019 Server out of Maintenance Mode.

.DESCRIPTION
   This script is created to automatically take an Exchange 2013 Server out of Maintenance Mode. 
   It will automatically detect if the server is a Mailbox Server and then take appropriate additional actions, if any.

   To execute the script, you will have to dot-source it first after which you can call the cmdlet: "Stop-ExchangeServerMaintenanceMode"
.EXAMPLE
   Running the following command will take a server called "Server1" out of Maintenance Mode:

   Stop-ExchangeServerMaintenanceMode.ps1 -Server Server1
#>

[CmdletBinding()]
[OutputType([int])]
Param
(
    # determine what server to put in maintenance mode
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true,
               Position=0)]
    [string]$Server
)


$discoveredServer = Get-ExchangeServer -Identity $Server | Select IsHubTransportServer,IsFrontendTransportServer,AdminDisplayVersion

#Check for Administrative credentials
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){
	Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

if($discoveredServer.AdminDisplayVersion.Major -ne "15"){
        Write-Warning "The specified Exchange Server is not an Exchange 2013 server!"
        Write-Warning "Aborting script..."
        Break
}


Write-Host "INFO: Reactivating all server components..." -ForegroundColor Yellow
    Set-ServerComponentState $server -Component ServerWideOffline -State Active -Requester Maintenance
Write-Host "INFO: Server component states changed back into active state using requester 'Maintenance'" -ForegroundColor Yellow

if($discoveredServer.IsHubTransportServer -eq $true){
                
    $mailboxserver = Get-MailboxServer -Identity $Server | Select DatabaseAvailabilityGroup
    
    if($mailboxserver.DatabaseAvailabilityGroup -ne $null){
        Write-Host "INFO: Server $server is a member of a Database Availability Group. Resuming the node now." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "INFO: Node information:" -ForegroundColor Green
        Write-Host "-----------------------" -ForegroundColor Green
        Invoke-Command -ComputerName $Server -ArgumentList $Server {Resume-ClusterNode $args[0]}
        Set-MailboxServer $Server -DatabaseCopyActivationDisabledAndMoveNow $false
        Set-MailboxServer $Server -DatabaseCopyAutoActivationPolicy Unrestricted
        Write-Host ""
        Write-Host ""
    }
    
    Write-Host "INFO: Resuming Transport Service..." -ForegroundColor Yellow
    Set-ServerComponentState -Identity $Server -Component HubTransport -State Active -Requester Maintenance

    Write-Host "INFO: Restarting the MSExchangeTransport Service on server $Server..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $Server {Restart-Service MSExchangeTransport} | Out-Null

}

#restart FE Transport Services if server is also CAS
if($discoveredServer.IsFrontendTransportServer -eq $true){
    Write-Host "INFO: Restarting the MSExchangeFrontEndTransport Service on server $Server..." -ForegroundColor Yellow
    Set-Service MSExchangeFrontEndTransport -StartupType Automatic
    Invoke-Command -ComputerName $Server {Restart-Service MSExchangeFrontEndTransport} | Out-Null
}
 
 $server = hostname
 Write-Host "INFO: Restarting the MSExchangeFrontEndTransport Service on server $Server..." -ForegroundColor Yellow


# Check Stopped Services
function CheckServices(){
   $i = 0
   $i = (get-wmiobject "Win32_Service" -ComputerName srvmail01 -ErrorAction SilentlyContinue | where {$_.name -like "MsExchange*" -and $_.name -notlike "edgeupdate" -and $_.name -notlike "MSExchangeDiagnostics" -and $_.name -NotLike "clr_optimization*" -and $_.startmode -eq 'Auto' -and $_.state -eq "stopped"}).count
   return $i
}


 
Write-Host "INFO: Checking Stopped Services in automatic Startup" -ForegroundColor Yellow
while (($StoppedServices = CheckServices) -ne 0)
{
get-wmiobject "Win32_Service" -ComputerName $server -ErrorAction SilentlyContinue | where {$_.name -NotLike "clr_optimization*" -and $_.startmode -eq 'Auto' -and $_.state -eq "stopped"} | select-object Name | Get-Service -ComputerName $server | start-service | out-null
start-sleep -Seconds 10
}


## Mount Databases not replicated in other DAG Members, those are still mounted
        Write-Host "INFO: Mounting, not mounted databases not replicated in DAG Members!" -ForegroundColor Yellow
        $DBs = $NULL
        $DBs = Get-MailboxDatabaseCopyStatus | Where-Object {$_.status -eq "Dismounted"}
        
        
        Foreach ($DB in $DBS)
        {
         $statusDB = (get-mailboxdatabase $DB.DatabaseName).replicationtype
         if ($DBs -ne $NULL -and $statusDB -eq "none")
         {
           Mount-Database $DB.databasename -Confirm:$false
           write-host "INFO: Mounted Database" $db.DatabaseName -ForeGroundColor Green
         }
         else 
         {
           write-host "INFO: All Databases not replicated in other Dag members are mounted!" -ForegroundColor Yellow
         }
        }

Write-Host ""
Write-Host "INFO: Done! Server $server successfully taken out of Maintenance Mode." -ForegroundColor Green
Write-Host ""

$ComponentStates = (Get-ServerComponentstate $Server).LocalStates | ?{$_.State -eq "InActive"}
if($ComponentStates){
    Write-Warning "There are still some components inactive on server $Server."
    Write-Warning "Some features might not work until all components are back in an Active state."
    Write-Warning "Check the information below to see what components are still in an inactive state and which requester put them in that state."
    $ComponentStates
    Clear-Variable ComponentStates
}
