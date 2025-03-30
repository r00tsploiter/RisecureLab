Set-ExecutionPolicy bypass
Unblock-File -Path *
$IP = "192.168.10.10"
$Hostname = "BranchA-dc"
$ParentDomain = "Risecure.lab"
$ParentDCIP = "10.10.10.10"
$Domain = "BranchA"
$ParentDomainAdminUsername = "Administrator@risecure.lab"
$ParentDomainAdminPassword = "P@ssw0rd12" # TODO: modify this
$SafeModeAdministratorPassword = "P@ssw0rd12"
$ProgressFile = "progress.txt"
$Progress = 0
$Gateway = "192.168.10.2"
$DNSServers = "10.10.10.10"

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
        New-Domain -Domain $Domain -ParentDomain $ParentDomain -SafeModeAdministratorPassword $SafeModeAdministratorPassword -ParentDomainAdminUsername $ParentDomainAdminUsername -ParentDomainAdminPassword $ParentDomainAdminPassword
        Write-Output 2 > $ProgressFile
        Restart-Computer
    }
    {$_ -le 2} {
        Write-Output "Installation Success"
    }
}
