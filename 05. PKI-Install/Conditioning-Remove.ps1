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
            Remove-Computer -Credential $credential -Workgroup -Force -Restart -ErrorAction Stop
            Write-Output "unjoined"
            Remove-Item -Path $ProgressFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Error "Failed to unjoin domain: $_"
            # Optionally handle the error here
        }
    }
    {$_ -le 2} {
        . .\pre-requisites
    }
}
