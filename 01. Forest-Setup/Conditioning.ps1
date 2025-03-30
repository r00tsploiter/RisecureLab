Set-ExecutionPolicy bypass
Unblock-File -Path *
$IP = "10.10.10.10"
$Hostname = "dc01"
$Domain = "Risecure.lab"
$DNSServers = "8.8.8.8"
$Password = "P@ssw0rd"
$ProgressFile = "progress.txt"
$Progress = 0
$Gateway = "10.10.10.2"

$ErrorActionPreference = "Skip"
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
        New-Forest -Domain $Domain -SafeModeAdministratorPassword $Password
        Write-Output 2 > $ProgressFile
	Start-Sleep -Seconds 60
        
    }
    {$_ -le 2} {
        Write-Output "Populating Active Directory"
        Import-module activedirectory
        
        #Declare any Variables
        $dirpath = $pwd.path
        $counter = 0

        #import CSV File
        $groups = Import-csv "$dirpath\AD-data\ADGroups.csv"
        $TotalImports = $groups.Count

        #Create Users
        $groups | ForEach-Object {
            $counter++
            $progress = [int]($counter / $totalImports * 100)
            Write-Progress -Activity "Provisioning AD Groups" -status "Provisioning group $counter of $TotalImports" -perc $progress

            foreach ($group in $groups) {
                New-ADGroup -Name $group.name -Description "New Groups Created in Bulk" -GroupCategory Security -GroupScope Universal -Managedby Administrator
            }
        }
        Write-Output 3 > $ProgressFile
    }

    {$_ -le 3} {
        Import-module activedirectory

        #Autopopulate Domain
        $dnsDomain = $env:userdnsdomain
        
        $split = $dnsDomain.split(".")
        $domain = $null
        foreach ($part in $split) {
            if ($null -ne $domain) {
                $domain += ","
            }
            $domain += "DC=$part"
        }
        
        #Declare any Variables
        $dirpath = $pwd.path
        $counter = 0
        
        #import CSV File
        $ImportFile = Import-csv "$dirpath\AD-data\ADUsers.csv"
        $TotalImports = $importFile.Count
        
        #Create Users
        $ImportFile | ForEach-Object {
            $counter++
            $progress = [int]($counter / $totalImports * 100)
            Write-Progress -Activity "Provisioning User Accounts" -status "Provisioning account $counter of $TotalImports" -perc $progress
            if ($_.Manager -eq "") {
                New-ADUser -SamAccountName $_."SamAccountName" -Name $_."Name" -Surname $_."Surname" -GivenName $_."GivenName" -AccountPassword (ConvertTo-SecureString $_."Password" -AsPlainText -Force) -Enabled $true -title $_."title" -officePhone $_."officePhone" -department $_."department" -emailaddress $_."Email" -Description $_."title"
            }
            else {
                New-ADUser -SamAccountName $_."SamAccountName" -Name $_."Name" -Surname $_."Surname" -GivenName $_."GivenName" -AccountPassword (ConvertTo-SecureString $_."Password" -AsPlainText -Force) -Enabled $true -title $_."title" -officePhone $_."officePhone" -department $_."department" -emailaddress $_."Email" -Description $_."title" -Manager $_."Manager"
            }
            if (Get-ChildItem "$dirpath\AD-data\userimages\$($_.name).jpg") {
                $photo = [System.IO.File]::ReadAllBytes("$dirpath\AD-data\userimages\$($_.name).jpg")
                Set-ADUSER $_.samAccountName -Replace @{thumbnailPhoto = $photo }
            }
            else {
                $photo = [System.IO.File]::ReadAllBytes("$dirpath\AD-data\userimages\user.jpg")
                Set-ADUSER $_.samAccountName -Replace @{thumbnailPhoto = $photo }
            }
        }
        Write-Output 3 > $ProgressFile

    }

    {$_ -le 4} {
        #Import Active Directory Module
        Import-module activedirectory

        #Declare any Variables
        $dirpath = $pwd.path
        $counter = 0

        #import CSV File
        $list = Import-csv "$dirpath\AD-data\ADGrouptoUserMapping.csv"
        $TotalImports = $list.Count

        # Add Users to Groups
        $list | ForEach-Object {
            $counter++
            $progress = [int]($counter / $totalImports * 100)
            Write-Progress -Activity "Add users to groups" -status "Action $counter of $TotalImports" -perc $progress

            foreach ($line in $list) {
                add-adgroupmember -identity $line.Group -members $line.SamAccountName
            }
        }
        Write-Output 5 > $ProgressFile
    }

    {$_ -le 5} {
        Import-Module ActiveDirectory 
        $comps = get-aduser -Filter { title -eq "IT Manager" -or title -eq "Service Account" } | Select-object -expandproperty SamAccountName
        $users = @()
        
        $Users = foreach ($comp in $comps) {
            Get-ADUser $comp
        }
        Add-ADGroupMember "Domain Admins" -Members $users
        Write-Output 6 > $ProgressFile
    }
    {$_ -le 6} {
        Write-Output "Done Configurations!!"

    }


}
