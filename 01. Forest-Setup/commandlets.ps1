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

function New-Forest {
    <#
    .SYNOPSIS
  
    Installs a new Active Directory forest with the supplied domain name, including DNS and optionally configures a server for DHCP.
  
    .DESCRIPTION
  
    This function installs a new Active Directory forest with the supplied domain name and configures DNS on the specified server (defaults to local machine). It attempts to install DHCP on the specified server but requires further manual configuration after forest creation (refer to Microsoft documentation).
  
    .PARAMETER Domain
  
    The domain name for the AD forest.
  
    .PARAMETER SafeModeAdministratorPassword
  
    The plaintext password for SafeModeAdministratorPassword.
  
    .PARAMETER DnsServerName (Optional)
  
    The name or IP address of the server to configure as a DNS server. Defaults to the local machine.
  
    .PARAMETER DhcpServerName (Optional)
  
    The name or IP address of the server to configure for DHCP. Defaults to the local machine.
  
    .EXAMPLE
  
    New-Forest -Domain test.local -SafeModeAdministratorPassword "P@ssw0rd!~" -DnsServerName DC01
  
    Installs a new AD forest "test.local" with DNS configured on server "DC01". DHCP installation is attempted on "DC01", but further manual configuration is required.
  
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,
  
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $SafeModeAdministratorPassword,
  
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $DnsServerName = ([System.Net.Dns]::GetHostName()),
  
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $DhcpServerName = ([System.Net.Dns]::GetHostName())
    )
  
    try {
      # Install required features
      Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools -Restart
  
      # Convert password to secure string
      $SecurePassword = ConvertTo-SecureString -String $SafeModeAdministratorPassword -AsPlainText -Force
  
      # Install AD DS with DNS
      Import-Module ADDSDeployment
      Install-ADDSForest `
      -CreateDnsDelegation:$false `
      -DatabasePath "C:\Windows\NTDS" `
      -DomainMode "WinThreshold" `
      -DomainName $Domain `
      -DomainNetbiosName "RISECURE-DC" `
      -ForestMode "WinThreshold" `
      -InstallDns:$true `
      -LogPath "C:\Windows\NTDS" `
      -NoRebootOnCompletion:$false `
      -SysvolPath "C:\Windows\SYSVOL" `
      -Force:$true
  
      # Attempt DHCP installation (manual configuration required later)
      Install-WindowsFeature -Name DHCP -IncludeManagementTools -ComputerName $DhcpServerName -Restart
      Write-Host "** DHCP server installation attempted on '$DhcpServerName'. Further manual configuration required. Refer to Microsoft documentation: https://learn.microsoft.com/en-us/windows-server/networking/technologies/dhcp/quickstart-install-configure-dhcp-server **"
    }
    catch {
      Write-Error "Error encountered during forest creation: $($_.Exception.Message)"
      # Optionally log the error or throw a terminating exception
    }
  }
  function Create-UserFromJson {
    <#
    .SYNOPSIS
    
    Create users listed in a json file.
    
    .DESCRIPTION
    
    This function creates users listed in a json file.
    The json file contains a object array. Each object must contains "Username" and "Password" field.
    
    .PARAMETER Path
    
    The file path of the json file.
    
    .EXAMPLE
    
    Create-UserFromJson -Path .\credentials.json
    
    Create user from credentials.json.
    
    #>
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [String]
            $Path
        )
        $Content = Get-Content $Path
        $Users = $Content | ConvertFrom-Json
        ForEach ($User in $Users) {
            $Username = $User.Username
            $Password = $User.Password
            if (Get-ADUser -Filter {SamAccountName -eq $Username}) {
                Write-Warning "The user '$Username' already exists"
            } Else {
                $SecurePassword = ConvertTo-SecureString $Password -Force -AsPlainText
                New-ADUser -Name $Username -AccountPassword $SecurePassword -PasswordNeverExpires $true -Enabled $true
            }
        }
    }