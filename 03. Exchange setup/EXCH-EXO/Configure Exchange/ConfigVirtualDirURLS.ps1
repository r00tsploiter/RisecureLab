####################################################################################################################################################################
#  SCRIPT DETAILS                                                                                                                                                  #
#    Configures internal and external urls of Exchange CAS Server/s vDirs                                                                                          #
#                                                                                                                                                                  #
#																				   #
# OTHER SCRIPT INFORMATION																	   #
#    Rights Required	: Admin on CAS Server															   #
#    Exchange Version	: 2016/2019                                                                                                                                #
#    Shell : Exchange Management Shell (Not Windows powershell, you'll need to leverage Exchange PS Module)                                                        #
#    Disclaimer   		: You are on your own.  This was not written by, supported by, or endorsed by Microsoft.      					   #
#                                                                                                                                                                  #
#    					                                                                                                                           #
#																				   #
# EXECUTION																			   #
#  .\ConfigureVirtualDirUrls.ps1 -InternalURL mail.contoso.com -ExternalURL mail.contoso.com -Server server1,server3 -AutodiscoverSCP autodiscover.contoso.com	   #
#																				   #
####################################################################################################################################################################


[CmdletBinding()]
param(
	[Parameter( Position=0,Mandatory=$true)]
	[string[]]$Server,

	[Parameter( Mandatory=$true)]
	[string]$InternalURL,

	[Parameter( Mandatory=$true)]
    [AllowEmptyString()]
	[string]$ExternalURL,

	[Parameter( Mandatory=$true)]
	[string]$AutodiscoverSCP,

    [Parameter( Mandatory=$false)]
    [Boolean]$InternalSSL=$true,

    [Parameter( Mandatory=$false)]
    [Boolean]$ExternalSSL=$true
	)


#...................................
# Script
#...................................

Begin {

    #Add Exchange snapin if not already loaded in the PowerShell session
    if (Test-Path $env:ExchangeInstallPath\bin\RemoteExchange.ps1)
    {
	    . $env:ExchangeInstallPath\bin\RemoteExchange.ps1
	    Connect-ExchangeServer -auto -AllowClobber
    }
    else
    {
        Write-Warning "Exchange Server management tools are not installed on this computer."
        EXIT
    }
}

Process {

    foreach ($i in $server)
    {
        if ((Get-ExchangeServer $i -ErrorAction SilentlyContinue).IsClientAccessServer)
        {
            Write-Host "----------------------------------------"
            Write-Host " Configuring $i"
            Write-Host "----------------------------------------`r`n"
            Write-Host "Values:"
            Write-Host " - Internal URL: $InternalURL"
            Write-Host " - External URL: $ExternalURL"
            Write-Host " - Outlook Anywhere internal SSL required: $InternalSSL"
            Write-Host " - Outlook Anywhere external SSL required: $ExternalSSL"
            Write-Host "`r`n"

            Write-Host "Configuring Outlook Anywhere URLs"
            $OutlookAnywhere = Get-OutlookAnywhere -Server $i
            $OutlookAnywhere | Set-OutlookAnywhere -ExternalHostname $externalurl -InternalHostname $internalurl `
                                -ExternalClientsRequireSsl $ExternalSSL -InternalClientsRequireSsl $InternalSSL `
                                -ExternalClientAuthenticationMethod $OutlookAnywhere.ExternalClientAuthenticationMethod

            if ($externalurl -eq "")
            {
                Write-Host "Configuring Outlook Web App URLs"
                Get-OwaVirtualDirectory -Server $i | Set-OwaVirtualDirectory -ExternalUrl $null -InternalUrl https://$internalurl/owa

                Write-Host "Configuring Exchange Control Panel URLs"
                Get-EcpVirtualDirectory -Server $i | Set-EcpVirtualDirectory -ExternalUrl $null -InternalUrl https://$internalurl/ecp

                Write-Host "Configuring ActiveSync URLs"
                Get-ActiveSyncVirtualDirectory -Server $i | Set-ActiveSyncVirtualDirectory -ExternalUrl $null -InternalUrl https://$internalurl/Microsoft-Server-ActiveSync

                Write-Host "Configuring Exchange Web Services URLs"
                Get-WebServicesVirtualDirectory -Server $i | Set-WebServicesVirtualDirectory -ExternalUrl $null -InternalUrl https://$internalurl/EWS/Exchange.asmx

                Write-Host "Configuring Offline Address Book URLs"
                Get-OabVirtualDirectory -Server $i | Set-OabVirtualDirectory -ExternalUrl $null -InternalUrl https://$internalurl/OAB

                Write-Host "Configuring MAPI/HTTP URLs"
                Get-MapiVirtualDirectory -Server $i | Set-MapiVirtualDirectory -ExternalUrl $null -InternalUrl https://$internalurl/mapi
            }
            else
            {
                Write-Host "Configuring Outlook Web App URLs"
                Get-OwaVirtualDirectory -Server $i | Set-OwaVirtualDirectory -ExternalUrl https://$externalurl/owa -InternalUrl https://$internalurl/owa

                Write-Host "Configuring Exchange Control Panel URLs"
                Get-EcpVirtualDirectory -Server $i | Set-EcpVirtualDirectory -ExternalUrl https://$externalurl/ecp -InternalUrl https://$internalurl/ecp

                Write-Host "Configuring ActiveSync URLs"
                Get-ActiveSyncVirtualDirectory -Server $i | Set-ActiveSyncVirtualDirectory -ExternalUrl https://$externalurl/Microsoft-Server-ActiveSync -InternalUrl https://$internalurl/Microsoft-Server-ActiveSync

                Write-Host "Configuring Exchange Web Services URLs"
                Get-WebServicesVirtualDirectory -Server $i | Set-WebServicesVirtualDirectory -ExternalUrl https://$externalurl/EWS/Exchange.asmx -InternalUrl https://$internalurl/EWS/Exchange.asmx

                Write-Host "Configuring Offline Address Book URLs"
                Get-OabVirtualDirectory -Server $i | Set-OabVirtualDirectory -ExternalUrl https://$externalurl/OAB -InternalUrl https://$internalurl/OAB

                Write-Host "Configuring MAPI/HTTP URLs"
                Get-MapiVirtualDirectory -Server $i | Set-MapiVirtualDirectory -ExternalUrl https://$externalurl/mapi -InternalUrl https://$internalurl/mapi
            }

            Write-Host "Configuring Autodiscover"
            if ($AutodiscoverSCP) {
                Get-ClientAccessServer $i | Set-ClientAccessServer -AutoDiscoverServiceInternalUri https://$AutodiscoverSCP/Autodiscover/Autodiscover.xml
            }
            else {
                Get-ClientAccessServer $i | Set-ClientAccessServer -AutoDiscoverServiceInternalUri https://$internalurl/Autodiscover/Autodiscover.xml
            }


            Write-Host "`r`n"
        }
        else
        {
            Write-Host -ForegroundColor Yellow "$i is not a Client Access server."
        }
    }
}

End {

    Write-Host "Finished processing all servers specified. Consider running Get-CASHealthCheck.ps1 to test your Client Access namespace and SSL configuration."
    Write-Host "Refer to http://exchangeserverpro.com/testing-exchange-server-2013-client-access-server-health-with-powershell/ for more details."

}

#...................................
# Finished
#...................................
