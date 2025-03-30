<#
.Synopsis
   Script to automatically put an Exchange 2013/2016/2019 into Maintenance Mode.


.DESCRIPTION
   This script is created to automatically put an Exchange 2013/2016/2019 Server into Maintenance Mode. 
   It will automatically detect if the server is a Mailbox Server and then take appropriate additional actions, if any.

.EXAMPLE
   Running the following command will place a server called "Server1" into Maintenance Mode and move any messages in transit from that server to "Server2".
   Please note that the TargetServer value has to be a FQDN!

   Start-ExchangeServerMaintenanceMode.ps1 -Server Server1 -TargetServerFQDN Server2
#>

[CmdletBinding()]
[OutputType([int])]
Param
(
    # determine what server to put in maintenance mode
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true,
               Position=0)]
    [string]$Server=$env:COMPUTERNAME,

    [Parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true,
               Position=1)]
    [string]$TargetServerFQDN
)

function evaluatequeues(){
    $fatto = 5
    while($fatto -ne 1){
       $error.clear()
       Get-Queue -Server $Server -erroraction continue >null 2>1
       if($error.count -ne 0){
          #write-host $fatto
          write-host "Pausa Warmup Transport"
          sleep 5  # attesa per aspettare consolidamento comandi precedenti -------------------------------------------------
          $fatto--
       } else {
          $fatto = 1
       }
    }
    
    $MessageCount = Get-Queue -Server $Server | ?{$_.Identity -notlike "*\Poison" -and $_.Identity -notlike"*\Shadow\*"} | Select MessageCount
    $count = 0
    Foreach($message in $MessageCount){
        $count += $message.messageCount
    }
    if($count -ne 0){
        Write-Output "INFO: Sleeping for 60 seconds before checking the transport queues again..." -ForegroundColor Yellow
        Start-Sleep -s 30
        evaluatequeues
    }
    else{
        Write-Host "INFO: Transport queues are empty." -ForegroundColor Yellow
        Write-Host "INFO: Putting the entire server into maintenance mode..." -ForegroundColor Yellow
        if(Set-ServerComponentState $Server -Component ServerWideOffline -State Inactive -Requester Maintenance){
            Write-Host "INFO: Done! The components of $Server have successfully been placed into an inactive state!"
        }
        Write-Host "INFO: Restarting MSExchangeTransport service on server $Server..." -ForegroundColor Yellow
            #Restarting transport services based on info from http://blogs.technet.com/b/exchange/archive/2013/09/26/server-component-states-in-exchange-2013.aspx
            #Restarting the services will cause the transport services to immediately pick up the changed state rather than having to wait for a MA responder to take action
            Invoke-Command -ComputerName $Server {Restart-Service MSExchangeTransport | Out-Null}
        
        #restart FE Transport Services if server is also CAS
        if($discoveredServer.IsFrontendTransportServer -eq $true){
            Write-Host "INFO: Restarting the MSExchangeFrontEndTransport Service on server $Server..." -ForegroundColor Yellow
            Invoke-Command -ComputerName $Server {Restart-Service MSExchangeFrontEndTransport} | Out-Null
        }
        Write-Host "INFO: Done! Server $Server is put succesfully into maintenance mode!" -ForegroundColor Green
    }

}

function checkMountedDB(){
   $i = 0
   $i = (Get-MailboxDatabaseCopyStatus -Server $Server | ? {$_.Status -eq "Mounted" }).count
   return $i
}

$discoveredServer = Get-ExchangeServer -Identity $Server | Select IsHubTransportServer,IsFrontendTransportServer,AdminDisplayVersion

#Check for Administrative credentials
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
	Break
}


#check if the server is an Exchange 2013/2016/2019/2016/2019 server
if($discoveredServer.AdminDisplayVersion.Major -ne "15"){
    Write-Warning "The specified Exchange Server is not an Exchange 2013/2016/2019/2016/2019 server!, try to type again the correct hostname"
    Write-Warning "Aborting script..."
    Break
}
else{

    if($discoveredServer.IsHubTransportServer -eq $True){
        if(-NOT ($TargetServerFQDN)){
            Write-Warning "TargetServerFQDN is required."
            $TargetServerFQDN = Read-Host -Prompt "Please enter the Queues TargetServerFQDN: "
        }
        
        #Get the FQDN of the Target Server through DNS, even if the input is just a host name
        try{
            $TargetServer = ([System.Net.Dns]::GetHostByName($TargetServerFQDN)).Hostname
        }
        catch{
            Write-Warning "Could not resolve ServerFQDN: $TargetServerFQDN";break
        }

        if((Get-ExchangeServer -Identity $TargetServer | Select IsHubTransportServer).IsHubTransportServer -ne $True){
            Write-Warning "The target server is not a valid Mailbox server."
            Write-Warning "Aborting script..."
            Break
        }

        #Redirecting messages to target system
        Write-Host "INFO: Suspending Transport Service. Draining remaining messages..." -ForegroundColor Yellow
        Set-ServerComponentState $Server -Component HubTransport -State Draining -Requester Maintenance
        Redirect-Message -Server $Server -Target $TargetServer -Confirm:$false

        #suspending cluster node (if the server is part of a DAG)
        $mailboxserver = Get-MailboxServer -Identity $Server | Select DatabaseAvailabilityGroup
        if($mailboxserver.DatabaseAvailabilityGroup -ne $null){
            Write-Host "INFO: Server $Server is a member of a Database Availability Group. Suspending the node now." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "INFO: Node information:" -ForegroundColor Yellow
            Write-Host "-----------------------" -ForegroundColor Yellow
            Invoke-Command -ComputerName $Server -ArgumentList $Server {Suspend-ClusterNode $args[0]}
            Set-MailboxServer $Server -DatabaseCopyActivationDisabledAndMoveNow $true
            Set-MailboxServer $Server -DatabaseCopyAutoActivationPolicy Blocked
            Write-Host ""
            Write-Host ""
        }

        #Evaluate the Transport Queues and put into maintenance mode once all queues are empty
        evaluatequeues

    }
    else{
        Write-Host "INFO: Server $Server is a Client Access Server-only server." -ForegroundColor Yellow
        Write-Host "INFO: Putting the server components into inactive state" -ForegroundColor Yellow
        Set-ServerComponentState $Server -Component ServerWideOffline -State Inactive -Requester Maintenance
        Write-Host "INFO: Restarting transport services..." -ForegroundColor Yellow
        if(Invoke-Command -ComputerName $Server {Restart-Service MSExchangeFrontEndTransport | Out-Null}){
            Write-Host "INFO: Successfully restarted MSExchangeFrontEndTransport service" -ForegroundColor Yellow
        }
        
       
    }

    ## Checking Mounted Databases ##
    while(($mountedDB = checkMountedDB) -ne 0){
        Write-Host -ForegroundColor Yellow "Waiting for DB's to complete the move process... Number of DB's still mounted on Server $($Server) is $($MountedDB)"
        Get-MailboxDatabaseCopyStatus -Server $Server | ? {$_.Status -eq "Mounted"}
        Sleep 10

        #Dismount Databases not replicated in other DAG Members, those are still mounted
        Write-Host "INFO: Dismounting databases not replicated in DAG Members!" -ForegroundColor Yellow
        $DBs = Get-MailboxDatabaseCopyStatus | Where-Object {$_.status -eq "mounted"}
        
        
        Foreach ($DB in $DBS)
        {
         $statusDB = (get-mailboxdatabase $DB.DatabaseName).replicationtype
         if ($StatusDB -eq "none")
         {
           Dismount-Database $DB.databasename -Confirm:$false
         }
        }
    }


    #Stop FrontEndTrasport
    write-host "INFO: Waiting 10 seconds before STOPPING and DISABLING MSExchangeFrontEndTransport" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Write-Host "INFO: Stopping and Disabling MSExchangeFrontEndTransport Node:"$Server -ForegroundColor Red
    Stop-Service MSExchangeFrontEndTransport
    Set-Service MSExchangeFrontEndTransport -StartupType Disabled
    
  $ip = Get-NetIPConfiguration
  $ipv4 = $ip.IPv4Address.ipaddress + ":443"
  $i = (netstat -an | findstr /c:$ipv4 | findstr ESTABLISHED).count

    while ($i -gt 10)
    {
    $ip = Get-NetIPConfiguration

     $activeConnections = (netstat -an | findstr /c:$ipv4 | findstr ESTABLISHED).count
     write-host "Ci sono ancora" $activeConnections "connessioni, attendere" -ForeGroundColor Red
    
    }
    Write-Host ""
    Write-Host "INFO: Done! Server $server successfully taken in Maintenance Mode." -ForegroundColor Green
    Write-Host ""
 
}
