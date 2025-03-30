Set-ExecutionPolicy bypass
Unblock-File -Path *
$IP = "10.10.10.30"
$Hostname = "Exch01"
$Domain = "Risecure.lab"
$DNSServers = "10.10.10.10"
$Password = "P@ssw0rd12"
$ProgressFile = "progress.txt"
$Progress = 0
$Gateway = "10.10.10.2"

$ErrorActionPreference = "Stop"
Import-Module .\commandlets.ps1

if (Test-Path $ProgressFile) {
    $Progress = [Int](Get-Content $ProgressFile)
}
Switch ($Progress) {
    {$_ -le 0} {
        if (-not (Test-Connection -ComputerName $Hostname -Quiet -Count 1)) {
            Set-Network -IP $IP -DNSServers $DNSServers -Gateway $Gateway
            Rename-Computer -NewName $Hostname -Force
            Write-Output 1 > $ProgressFile
            Restart-Computer
        }else {
            Write-Output "Computer name or network configuration already set."
        }
    }
    {$_ -le 1} {
        try {
            Add-Computer -DomainName $Domain -Credential $credential -Restart -ErrorAction Stop
            Write-Output "joined"
            Write-Output 2 > $ProgressFile
            Start-Sleep -Seconds 60
        } catch {
            Write-Error "Failed to join domain: $_"
            # Optionally handle the error here
        }
    }
    {$_ -le 2} {
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Error "Please run this script as an Administrator for $Domain."
            Exit
        }
        # Install required Windows features and roles for Exchange Server 2019
        Write-Output "Checking and installing prerequisites for Exchange Server 2019..."

        # Install .NET Framework 4.8
        if (-not (Get-WindowsFeature -Name NET-Framework-45-Core).Installed) {
            Write-Output "Installing .NET Framework 4.8..."
            Install-WindowsFeature -Name NET-Framework-45-Core -IncludeManagementTools
        }
        # Install Windows Server features required by Exchange Server
        $exchangeFeatures = @(
            "server-Media-Foundation", 
            "NET-Framework-45-Features", 
            "RPC-over-HTTP-proxy", 
            "RSAT-Clustering", 
            "RSAT-Clustering-CmdInterface", 
            "RSAT-Clustering-Mgmt", 
            "RSAT-Clustering-PowerShell", 
            "WAS-Process-Model", 
            "Web-Asp-Net45", 
            "Web-Basic-Auth", 
            "Web-Client-Auth", 
            "Web-Digest-Auth", 
            "Web-Dir-Browsing", 
            "Web-Dyn-Compression", 
            "Web-Http-Errors", 
            "Web-Http-Logging", 
            "Web-Http-Redirect", 
            "Web-Http-Tracing", 
            "Web-ISAPI-Ext", 
            "Web-ISAPI-Filter", 
            "Web-Lgcy-Mgmt-Console", 
            "Web-Metabase", 
            "Web-Mgmt-Console", 
            "Web-Mgmt-Service", 
            "Web-Net-Ext45", 
            "Web-Request-Monitor", 
            "Web-Server", 
            "Web-Stat-Compression", 
            "Web-Static-Content", 
            "Web-Windows-Auth", 
            "Web-WMI", 
            "Windows-Identity-Foundation", 
            "RSAT-ADDS"
        )

        foreach ($feature in $exchangeFeatures) {
            if (-not (Get-WindowsFeature -Name $feature).Installed) {
                Write-Output "Installing $feature..."
                Install-WindowsFeature -Name $feature -IncludeManagementTools
            }
        }
        # Define paths to downloaded installer files
        $vcRedistPath2012 = "Z:\Exchange\vcredist_x64 (2).exe"
        $vcRedistPath2013 = "Z:\Exchange\vcredist_x64.exe"
        $vcRedistPath2013_32bit = "Z:\Exchange\vcredist_x86.exe"
        $dotNetPath = "Z:\Exchange\ndp48-x86-x64-allos-enu.exe"
        $UCMARuntimePath = "Z:\Exchange\UcmaRuntimeSetup.exe"
        
        # Install VCRedist2012
        Start-Process -FilePath $vcRedistPath2012 -ArgumentList "/install /passive /norestart" -Wait
        # Install VCRedist2013
        Start-Process -FilePath $vcRedistPath2013 -ArgumentList "/install /passive /norestart" -Wait
        # Install VCRedist2013_32bit
        Start-Process -FilePath $vcRedistPath2012 -ArgumentList "/install /passive /norestart" -Wait
        
        # Install .NET Framework
        Start-Process -FilePath $dotNetPath -ArgumentList "/q /norestart" -Wait
        
        # Install other necessary runtime
        Start-Process -FilePath $UCMARuntimePath -ArgumentList "/quiet /norestart" -Wait
        
        Write-Output "Prerequisites check and installation complete."
        Write-Output 3 > $ProgressFile
        
    }
    {$_ -le 3} {
        
        $exchangeIsoPath = "Z:\Exchange\Exchange.iso"
        Write-Output "Copying ISO to local Disk and Mount."
        # Destination drive for copying the ISO (E: in this example)
        $destinationDrive = "E:\"

        # Copy Exchange ISO to destination drive
        Copy-Item -Path $exchangeIsoPath -Destination $destinationDrive -Force
        
        Restart-Computer
 
    }

}
