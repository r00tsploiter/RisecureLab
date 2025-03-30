start-Transcript -Verbose -NoClobber -LiteralPath C:\script\TLS\LogDisableTLS.txt

#### Disable SSL3.0 ####
write-host "Disabling SSL3.0 protocol"
$SSL3MainKey = "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0"

New-Item "$SSL3MainKey\Client\" -Force
Set-ItemProperty "$SSL3MainKey\Client\" -Name "DisabledByDefault" -Value 1 -Type Dword
Set-ItemProperty "$SSL3MainKey\Client" -Name "Enabled" -Value 0 -Type Dword
Write-host "I have disabled SSLV3 on CLIENT registry key and these are the results:" -ForegroundColor red
get-ItemProperty "$SSL3MainKey\Client\"


New-Item "$SSL3MainKey\Server\" -Force
Set-ItemProperty "$SSL3MainKey\Server\" -Name "DisabledByDefault" -Value 1 -Type Dword
Set-ItemProperty "$SSL3MainKey\Server\" -Name "Enabled" -Value 0 -Type Dword
Write-host "I have disabled SSLV3 on Server registry key and these are the results:" -ForegroundColor red
get-ItemProperty "$SSL3MainKey\Server\"
#### End Disable SSL3.0 ####


#### Disable SSL2.0 ####
write-host "Disabling SSL2.0 protocol" -ForegroundColor Green
$SSL2MainKey = "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0"

New-Item "$SSL2MainKey\Client\" -Force
Set-ItemProperty "$SSL2MainKey\Client\" -Name "DisabledByDefault" -Value 1 -Type Dword
Set-ItemProperty "$SSL2MainKey\Client\" -Name "Enabled" -Value 0 -Type Dword
Write-host "I have disabled SSLV2 on CLIENT registry key and these are the results:" -ForegroundColor red
get-ItemProperty "$SSL2MainKey\Client\"


New-Item "$SSL2MainKey\Server\" -Force
Set-ItemProperty "$SSL2MainKey\Server\" -Name "DisabledByDefault" -Value 1 -Type Dword
Set-ItemProperty "$SSL2MainKey\Server\" -Name "Enabled" -Value 0 -Type Dword
Write-host "I have disabled SSLV2 on CLIENT registry key and these are the results:" -ForegroundColor red
get-ItemProperty "$SSL3MainKey\Server\"

#### End Disable SSL2.0 ####


#### Disable TLS1.0 ####
write-host "Disabling TLS1.0 protocol" -ForegroundColor Green
$TLS1MainKey = "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0"

New-Item "$TLS1MainKey\Client\" -Force
Set-ItemProperty "$TLS1MainKey\Client\" -Name "DisabledByDefault" -Value 1 -Type Dword
Set-ItemProperty "$TLS1MainKey\Client\" -Name "Enabled" -Value 0 -Type Dword
Write-host "I have disabled TLS1.0 on CLIENT registry key and these are the results:" -ForegroundColor red
get-ItemProperty "$TLS1MainKey\Client\"


New-Item "$TLS1MainKey\Server\" -Force
Set-ItemProperty "$TLS1MainKey\Server\" -Name "DisabledByDefault" -Value 1 -Type Dword
Set-ItemProperty "$TLS1MainKey\Server\" -Name "Enabled" -Value 0 -Type Dword
Write-host "I have disabled TLS1.0 on Server registry key and these are the results:" -ForegroundColor red
get-ItemProperty "$TLS1MainKey\Server\"
#### End Disable TLS1.0 ####

#### Disable TLS1.1 ####
write-host "Disabling TLS1.1 protocol" -ForegroundColor Green
$TLS11MainKey = "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1"

New-Item "$TLS11MainKey\Client\" -Force
Set-ItemProperty "$TLS11MainKey\Client\" -Name "DisabledByDefault" -Value 1 -Type Dword
Set-ItemProperty "$TLS11MainKey\Client\" -Name "Enabled" -Value 0 -Type Dword
Write-host "I have disabled TLS1.1 on CLIENT registry key and these are the results:" -ForegroundColor red
get-ItemProperty "$TLS11MainKey\Client\"

New-Item "$TLS11MainKey\Server\" -Force
Set-ItemProperty "$TLS11MainKey\Server\" -Name "DisabledByDefault" -Value 1 -Type Dword
Set-ItemProperty "$TLS11MainKey\Server\" -Name "Enabled" -Value 0 -Type Dword
Write-host "I have disabled TLS1.1 on Server registry key and these are the results:" -ForegroundColor red
get-ItemProperty "$TLS11MainKey\Server\"
#### End Disable TLS1.1 ####



### Check TLS 1.2 Registry Key, create key and DWORD Values if doesn't exist ###

$registryPath = 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'
$client = "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\client"
$server = "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\server"
$name = "DisabledByDefault"
$value = "0"
$name1 = "Enabled"
$value1 = "1"

$checkValueClient = get-ItemProperty $client -name $Name -ErrorAction SilentlyContinue
$CheckValueClient1 = get-ItemProperty $Client -name $name1 -ErrorAction SilentlyContinue
$CheckValueServer = get-ItemProperty $Server -name $Name -ErrorAction SilentlyContinue
$CheckValueServer1 = get-ItemProperty $Server -name $Name1 -ErrorAction SilentlyContinue



if (!(Test-Path -Path $registryPath) -or $checkValueClient.DisabledByDefault -ne 0 -or $CheckValueClient1.enabled -ne 1 -or $checkValueServer.DisabledByDefault -ne 0 -or $CheckValueServer1.enabled -ne 1) {
    [void] (New-Item -Path $registryPath -Force)
    [void] (New-Item -Path $client -Force)
    [void] (New-Item -Path $server -Force)
    [void] (Set-ItemProperty -Path $client -Name $name -Value $value -Type DWORD -Force)
    [void] (Set-ItemProperty -Path $client -Name $name1 -Value $value1 -Type DWORD -Force)
    [void] (Set-ItemProperty -Path $server -Name $name -Value $value -Type DWORD -Force)
    [void] (Set-ItemProperty -Path $server -Name $name1 -Value $value1 -Type DWORD -Force)
    
    Write-host "Finished creating keys and DWORD values for TLS 1.2" -ForeGroundColor Green
}

Else
{
    Write-host "Key and related DWORD values exists" -ForegroundColor Green
}

### End TLS 1.2 Checks ###


Write-host "Done! Disabled ALL Legacy TLS Protocols, and enabled only TLS 1.2 Protocol" -ForegroundColor Red

stop-Transcript
