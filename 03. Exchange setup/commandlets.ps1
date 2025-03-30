function Set-Network {
    <#
    .SYNOPSIS
    
    Set IP address, DNS server, and gateway for a specified interface.
    
    .DESCRIPTION
    
    This function sets the IP address, DNS server, and gateway for the specified interface index.
    
    .PARAMETER IP
    
    The IP address for the computer.
    
    .PARAMETER DNSServers
    
    The IP address list of the DNS servers.
    
    .PARAMETER Gateway
    
    The IP address of the gateway.

    .PARAMETER IfIndex
    
    The index of the network adapter (listing adapters with Get-NetAdapter).
    
    .EXAMPLE
    
    Set-Network -IP 10.0.1.1 -DNSServers 8.8.8.8 -Gateway 10.0.1.254
    
    Set IP address to 10.0.1.1, set DNS server to 8.8.8.8, and set gateway to 10.0.1.254 for the first network adapter.
    
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidatePattern('\b(?:\d{1,3}\.){3}\d{1,3}\b')]
        [String]
        $IP,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $DNSServers,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('\b(?:\d{1,3}\.){3}\d{1,3}\b')]
        [String]
        $Gateway,

        [ValidateNotNull()]
        [Uint32]
        $IfIndex = ((Get-NetAdapter).ifIndex | Select-Object -First 1)
    )

    try {
        if (Get-NetIPAddress | ?{$_.InterfaceIndex -eq $IfIndex}) {
            Remove-NetIPAddress -IfIndex $IfIndex -Confirm:$false
        }
        New-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $IP -PrefixLength 24
        Set-DnsClientServerAddress -InterfaceIndex $IfIndex -ServerAddresses $DNSServers
        Set-NetIPInterface -InterfaceIndex $IfIndex -AddressFamily IPv4 -Dhcp Disabled
        New-NetRoute -InterfaceIndex $IfIndex -DestinationPrefix 0.0.0.0/0 -NextHop $Gateway

        Write-Output "Network configuration set successfully."
    } catch {
        Write-Error "An error occurred while setting network configuration: $_"
    }
    
    # Logging
    $logMessage = "Network configuration set for Interface Index $IfIndex - IP: $IP, DNS Servers: $($DNSServers -join ', '), Gateway: $Gateway"
    Write-Output $logMessage
    Add-Content -Path "C:\SetNetworkLog.txt" -Value $logMessage
}
