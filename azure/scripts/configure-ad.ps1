[CmdletBinding()]
Param(
  [string] $DomainName = "docker.local",
  [string] $DomainNetbiosName = "docker",
  [securestring] $DomainPassword,
  [string] $DomainFunctionalLevel = "Win2012R2"
)

function Install-ADDomainController {
  # ----
  # based on https://gist.github.com/PatrickLang/27c743782fca17b19bf94490cbb6f960 - credit Patrick Lang
  # ----

  # Install AD Services
  Install-WindowsFeature AD-Domain-Services
  # Import AD Domain Service Deployment module
  Import-Module ADDSDeployment

  # Configure Domain Forest
  Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainNetbiosName -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode $DomainFunctionalLevel -ForestMode $DomainFunctionalLevel -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -SafeModeAdministratorPassword $DomainPasswordSecure -Force:$true
  # Machine Restart

  
  
}

function Schedule-ActionOnRestart {
  # Do not do this in production. Just for POC purposes
  $action = New-ScheduledTaskAction -Execute 'Powershell' `
    -Argument '-NoProfile -WindowStyle Hidden -Command "Add-KdsRootKey –EffectiveTime ((get-date).addhours(-10))"'
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Complete AD Config"
}

Install-ADDomainController
Schedule-ActionOnRestart
