function Export-DistributionGroup2Cloud
{
  <#
      .SYNOPSIS
      Function to convert/migrate on-premises Exchange distribution group to a Cloud (Exchange Online) distribution group

      .DESCRIPTION
      Copies attributes of a synchronized group to a placeholder group and CSV file.
      After initial export of group attributes, the on-premises group can have the attribute "AdminDescription" set to "Group_NoSync" which will stop it from be synchronized.
      So before proceeding with the "finalize" switch of the DL you'll need to stop syncing the DL from the On-Premises Directory, in this way you can add all SMTP Addresses to the DL in Cloud.
      Before finalizing you have to be sure about the SMTP Flow from your On-Premises organization to Exchange Online!!
      The "-Finalize" switch can then be used to write the addresses to the new group and convert the name.  The final group will be a cloud group with the same attributes as the previous but with the additional ability of being able to be "self-managed".
      Once the contents of the new group are validated, the on-premises group can be deleted.

      .PARAMETER Group
      Name of group to recreate.

      .PARAMETER CreatePlaceHolder
      Create placeholder DistributionGroup wit ha given name.

      .PARAMETER Finalize
      Convert a given placeholder group to final DistributionGroup.

      .PARAMETER ExportDirectory
      Export Directory for internal CSV handling.

      .EXAMPLE
      PS> Export-DistributionGroup2Cloud -Group "DL-Marketing" -CreatePlaceHolder

      Create the Placeholder for the distribution group "DL-Marketing"

      .EXAMPLE
      PS> Export-DistributionGroup2Cloud -Group "DL-Marketing" -Finalize

      Transform the Placeholder for the distribution group "DL-Marketing" to the real distribution group in the cloud

      .NOTES
      This function is based on the Recreate-DistributionGroup.ps1 script of Joe Palarchio

  #>
  [CmdletBinding(ConfirmImpact = 'Low')]
  param
  (
    [Parameter(Mandatory,
    HelpMessage = 'Name of group to recreate.')]
    [string]
    $Group,
    [switch]
    $CreatePlaceHolder,
    [switch]
    $Finalize,
    [ValidateNotNullOrEmpty()]
    [string]
    $ExportDirectory = 'C:\scripts\PowerShell\exports\ExportedAddresses\'
  )

  begin
  {
    
    $SCN = 'SilentlyContinue'
    $CNT = 'Continue'
    $STP = 'Stop'
  }

  process
  {
    If ($CreatePlaceHolder.IsPresent)
    {
      
      If (((Get-DistributionGroup -Identity $Group -ErrorAction $SCN).IsValid) -eq $True)
      {
        
        $paramGetDistributionGroup = @{
          Identity      = $Group
          ErrorAction   = $STP
          WarningAction = $CNT
        }
        try
        {
          $OldDG = (Get-DistributionGroup @paramGetDistributionGroup)
        }
        catch
        {
          $line = ($_.InvocationInfo.ScriptLineNumber)

          
          Write-Warning -Message ('Error was in Line {0}' -f $line)

          
          Write-Error -Message $_ -ErrorAction $STP

          
          break
        }

        try
        {
          [IO.Path]::GetInvalidFileNameChars() | ForEach-Object -Process {
            $Group = $Group.Replace($_,'_')
          }
        }
        catch
        {
          $line = ($_.InvocationInfo.ScriptLineNumber)

          
          Write-Warning -Message ('Error was in Line {0}' -f $line)

          
          Write-Error -Message $_ -ErrorAction $STP

          
          break
        }

        $OldName = [string]$OldDG.Name
        $OldDisplayName = [string]$OldDG.DisplayName
        $OldPrimarySmtpAddress = [string]$OldDG.PrimarySmtpAddress
        $OldAlias = [string]$OldDG.Alias

        
        $paramGetDistributionGroupMember = @{
          Identity      = $OldDG.Name
          ErrorAction   = $STP
          WarningAction = $CNT
        }
        try
        {
          $OldMembers = ((Get-DistributionGroupMember @paramGetDistributionGroupMember).Name)
        }
        catch
        {
          $line = ($_.InvocationInfo.ScriptLineNumber)

         
          Write-Warning -Message ('Error was in Line {0}' -f $line)

          
          Write-Error -Message $_ -ErrorAction $STP

          
          break
        }

        If(!(Test-Path -Path $ExportDirectory -ErrorAction $SCN -WarningAction $CNT))
        {
          Write-Verbose -Message ('  Creating Directory: {0}' -f $ExportDirectory)

          
          $paramNewItem = @{
            ItemType      = 'directory'
            Path          = $ExportDirectory
            Force         = $True
            Confirm       = $False
            ErrorAction   = $STP
            WarningAction = $CNT
          }
          try
          {
            $null = (New-Item @paramNewItem)
          }
          catch
          {
            $line = ($_.InvocationInfo.ScriptLineNumber)

            
            Write-Warning -Message ('Error was in Line {0}' -f $line)

            
            Write-Error -Message $_ -ErrorAction $STP

            
            break
          }
        }

         
        $ExportDirectoryGroupCsv = $ExportDirectory + '\' + $Group + '.csv'

        try
        {
          
          'EmailAddress' > $ExportDirectoryGroupCsv
          $OldDG.EmailAddresses >> $ExportDirectoryGroupCsv
          'x500:'+$OldDG.LegacyExchangeDN >> $ExportDirectoryGroupCsv
        }
        catch
        {
          $line = ($_.InvocationInfo.ScriptLineNumber)

          
          Write-Warning -Message ('Error was in Line {0}' -f $line)

          
          Write-Error -Message $_ -ErrorAction $STP

          
          break
        }

        
        $NewDistributionGroupName = 'Cloud-' + $OldName
        $NewDistributionGroupAlias = 'Cloud-' + $OldAlias
        $NewDistributionGroupDisplayName = 'Cloud-' + $OldDisplayName
        $NewDistributionGroupPrimarySmtpAddress = 'Cloud-' + $OldPrimarySmtpAddress

        
        Write-Output -InputObject ('  Creating Group: {0}' -f $NewDistributionGroupDisplayName) -Verbose

        
        $paramNewDistributionGroup = @{
          Name               = $NewDistributionGroupName
          Alias              = $NewDistributionGroupAlias
          DisplayName        = $NewDistributionGroupDisplayName
          ManagedBy          = $OldDG.ManagedBy
          Members            = $OldMembers
          PrimarySmtpAddress = $NewDistributionGroupPrimarySmtpAddress
          ErrorAction        = $STP
          WarningAction      = $CNT
        }
        try
        {
          $null = (New-DistributionGroup @paramNewDistributionGroup)
        }
        catch
        {
          $line = ($_.InvocationInfo.ScriptLineNumber)
          
          Write-Warning -Message ('Error was in Line {0}' -f $line)

          
          Write-Error -Message $_ -ErrorAction $STP

          # Breaking down, you have to choose a switch!!
          break
        }

        # Wait for 3 seconds
        $null = (Start-Sleep -Seconds 3)

        
        $SetDistributionGroupIdentity = 'Cloud-' + $OldName
        $SetDistributionGroupDisplayName = 'Cloud-' + $OldDisplayName

        
        Write-Output -InputObject ('  Setting Values For: {0}' -f $SetDistributionGroupDisplayName)

        
        $paramSetDistributionGroup = @{
          Identity                               = $SetDistributionGroupIdentity
          AcceptMessagesOnlyFromSendersOrMembers = $OldDG.AcceptMessagesOnlyFromSendersOrMembers
          RejectMessagesFromSendersOrMembers     = $OldDG.RejectMessagesFromSendersOrMembers
          ErrorAction                            = $STP
          WarningAction                          = $CNT
        }
        try
        {
          $null = (Set-DistributionGroup @paramSetDistributionGroup)
        }
        catch
        {
          $line = ($_.InvocationInfo.ScriptLineNumber)

          
          Write-Warning -Message ('Error was in Line {0}' -f $line)

          
          Write-Error -Message $_ -ErrorAction $STP

          
          break
        }

        
        $SetDistributionGroupIdentity = 'Cloud-' + $OldName

        
        $paramSetDistributionGroup = @{
          Identity                             = $SetDistributionGroupIdentity
          AcceptMessagesOnlyFrom               = $OldDG.AcceptMessagesOnlyFrom
          AcceptMessagesOnlyFromDLMembers      = $OldDG.AcceptMessagesOnlyFromDLMembers
          BypassModerationFromSendersOrMembers = $OldDG.BypassModerationFromSendersOrMembers
          BypassNestedModerationEnabled        = $OldDG.BypassNestedModerationEnabled
          CustomAttribute1                     = $OldDG.CustomAttribute1
          CustomAttribute2                     = $OldDG.CustomAttribute2
          CustomAttribute3                     = $OldDG.CustomAttribute3
          CustomAttribute4                     = $OldDG.CustomAttribute4
          CustomAttribute5                     = $OldDG.CustomAttribute5
          CustomAttribute6                     = $OldDG.CustomAttribute6
          CustomAttribute7                     = $OldDG.CustomAttribute7
          CustomAttribute8                     = $OldDG.CustomAttribute8
          CustomAttribute9                     = $OldDG.CustomAttribute9
          CustomAttribute10                    = $OldDG.CustomAttribute10
          CustomAttribute11                    = $OldDG.CustomAttribute11
          CustomAttribute12                    = $OldDG.CustomAttribute12
          CustomAttribute13                    = $OldDG.CustomAttribute13
          CustomAttribute14                    = $OldDG.CustomAttribute14
          CustomAttribute15                    = $OldDG.CustomAttribute15
          ExtensionCustomAttribute1            = $OldDG.ExtensionCustomAttribute1
          ExtensionCustomAttribute2            = $OldDG.ExtensionCustomAttribute2
          ExtensionCustomAttribute3            = $OldDG.ExtensionCustomAttribute3
          ExtensionCustomAttribute4            = $OldDG.ExtensionCustomAttribute4
          ExtensionCustomAttribute5            = $OldDG.ExtensionCustomAttribute5
          GrantSendOnBehalfTo                  = $OldDG.GrantSendOnBehalfTo
          HiddenFromAddressListsEnabled        = $True
          MailTip                              = $OldDG.MailTip
          MailTipTranslations                  = $OldDG.MailTipTranslations
          MemberDepartRestriction              = $OldDG.MemberDepartRestriction
          MemberJoinRestriction                = $OldDG.MemberJoinRestriction
          ModeratedBy                          = $OldDG.ModeratedBy
          ModerationEnabled                    = $OldDG.ModerationEnabled
          RejectMessagesFrom                   = $OldDG.RejectMessagesFrom
          RejectMessagesFromDLMembers          = $OldDG.RejectMessagesFromDLMembers
          ReportToManagerEnabled               = $OldDG.ReportToManagerEnabled
          ReportToOriginatorEnabled            = $OldDG.ReportToOriginatorEnabled
          RequireSenderAuthenticationEnabled   = $OldDG.RequireSenderAuthenticationEnabled
          SendModerationNotifications          = $OldDG.SendModerationNotifications
          SendOofMessageToOriginatorEnabled    = $OldDG.SendOofMessageToOriginatorEnabled
          BypassSecurityGroupManagerCheck      = $True
          ErrorAction                          = $STP
          WarningAction                        = $CNT
        }
        try
        {
          $null = (Set-DistributionGroup @paramSetDistributionGroup)
        }
        catch
        {
          $line = ($_.InvocationInfo.ScriptLineNumber)
          
          Write-Warning -Message ('Error was in Line {0}' -f $line)

          
          Write-Error -Message $_ -ErrorAction $STP

          
          break
        }
      }
      Else
      {
        Write-Error -Message ('The distribution group {0} was not found' -f $Group) -ErrorAction $CNT
      }
    }
    ElseIf ($Finalize.IsPresent)
    {
      

      
      $GetDistributionGroupIdentity = 'Cloud-' + $Group

      
      $paramGetDistributionGroup = @{
        Identity      = $GetDistributionGroupIdentity
        ErrorAction   = $STP
        WarningAction = $CNT
      }
      try
      {
        $TempDG = (Get-DistributionGroup @paramGetDistributionGroup)
      }
      catch
      {
        $line = ($_.InvocationInfo.ScriptLineNumber)

        
        Write-Warning -Message ('Error was in Line {0}' -f $line)

        
        Write-Error -Message $_ -ErrorAction $STP

        
        break
      }

      $TempPrimarySmtpAddress = $TempDG.PrimarySmtpAddress

      try
      {
        [IO.Path]::GetInvalidFileNameChars() | ForEach-Object -Process {
          $Group = $Group.Replace($_,'_')
        }
      }
      catch
      {
        $line = ($_.InvocationInfo.ScriptLineNumber)

        
        Write-Warning -Message ('Error was in Line {0}' -f $line)

        
        Write-Error -Message $_ -ErrorAction $STP

        
        break
      }

      $OldAddressesPatch = $ExportDirectory + '\' + $Group + '.csv'

      
      $paramImportCsv = @{
        Path          = $OldAddressesPatch
        ErrorAction   = $STP
        WarningAction = $CNT
      }
      try
      {
        $OldAddresses = @(Import-Csv @paramImportCsv)
      }
      catch
      {
        $line = ($_.InvocationInfo.ScriptLineNumber)

        
        Write-Warning -Message ('Error was in Line {0}' -f $line)

        
        Write-Error -Message $_ -ErrorAction $STP

        
        break
      }

      try
      {
        $NewAddresses = $OldAddresses | ForEach-Object -Process {
          $_.EmailAddress.Replace('X500','x500')
        }
      }
      catch
      {
        $line = ($_.InvocationInfo.ScriptLineNumber)

        
        Write-Warning -Message ('Error was in Line {0}' -f $line)

        
        Write-Error -Message $_ -ErrorAction $STP

        
        break
      }

      $NewDGName = $TempDG.Name.Replace('Cloud-','')
      $NewDGDisplayName = $TempDG.DisplayName.Replace('Cloud-','')
      $NewDGAlias = $TempDG.Alias.Replace('Cloud-','')

      try
      {
        $NewPrimarySmtpAddress = ($NewAddresses | Where-Object -FilterScript {
            $_ -clike 'SMTP:*'
        }).Replace('SMTP:','')
      }
      catch
      {
        $line = ($_.InvocationInfo.ScriptLineNumber)
        
        Write-Warning -Message ('Error was in Line {0}' -f $line)

        
        Write-Error -Message $_ -ErrorAction $STP

        
        break
      }

      
      $paramSetDistributionGroup = @{
        Identity                        = $TempDG.Name
        Name                            = $NewDGName
        Alias                           = $NewDGAlias
        DisplayName                     = $NewDGDisplayName
        PrimarySmtpAddress              = $NewPrimarySmtpAddress
        HiddenFromAddressListsEnabled   = $False
        BypassSecurityGroupManagerCheck = $True
        ErrorAction                     = $STP
        WarningAction                   = $CNT
      }
      try
      {
        $null = (Set-DistributionGroup @paramSetDistributionGroup)
      }
      catch
      {
        $line = ($_.InvocationInfo.ScriptLineNumber)
        
        Write-Warning -Message ('Error was in Line {0}' -f $line)

        
        Write-Error -Message $_ -ErrorAction $STP

        
        break
      }

      $paramSetDistributionGroup = @{
        Identity                        = $NewDGName
        EmailAddresses                  = @{
          Add = $NewAddresses
        }
        BypassSecurityGroupManagerCheck = $True
        ErrorAction                     = $STP
        WarningAction                   = $CNT
      }
      try
      {
        $null = (Set-DistributionGroup @paramSetDistributionGroup)
      }
      catch
      {
        $line = ($_.InvocationInfo.ScriptLineNumber)
        
        Write-Warning -Message ('Error was in Line {0}' -f $line)

        
        Write-Error -Message $_ -ErrorAction $STP

        # Breaking down, you have to choose a switch!!
        break
      }

      
      $paramSetDistributionGroup = @{
        Identity                        = $NewDGName
        EmailAddresses                  = @{
          Remove = $TempPrimarySmtpAddress
        }
        BypassSecurityGroupManagerCheck = $True
        ErrorAction                     = $STP
        WarningAction                   = $CNT
      }
      try
      {
        $null = (Set-DistributionGroup @paramSetDistributionGroup)
      }
      catch
      {
        $line = ($_.InvocationInfo.ScriptLineNumber)

        # Dump the Info
        Write-Warning -Message ('Error was in Line {0}' -f $line)

        # Dump the Error catched
        Write-Error -Message $_ -ErrorAction $STP

        # Breaking down, you have to choose a switch!!
        break
      }
    }
    Else
    {
      Write-Error -Message "  ERROR: No options selected, please use '-CreatePlaceHolder' or '-Finalize'" -ErrorAction $STP

      # Breaking down, you have to choose a switch!!
      break
    }
  }

  end
  {
    
  }
}
