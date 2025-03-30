Set-ExecutionPolicy bypass
Unblock-File -Path *
$IP = "10.10.10.25"
$Hostname = "CA-02"
$Domain = "Risecure.lab"
$SubordinateCAName = "RisecureLab-SubCA"
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
        try {
            # We need to add the root CA cert to the Sub
            Add-WindowsFeature -Name ADCS-Cert-Authority, ADCS-Web-Enrollment, Web-Mgmt-Service -IncludeManagementTools | Out-Null
            Install-AdcsCertificationAuthority -CAType EnterpriseSubordinateCA -CACommonName $SubordinateCAName -KeyLength 4096 -HashAlgorithm SHA256 -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -Force | Out-Null

        } catch {
            Write-Error "Failde to Execute!!"
            # Optionally handle the error here
        }
    }
}
