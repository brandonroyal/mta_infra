[CmdletBinding()]
Param(
  [string] $DomainName = "docker.local",
  [string] $DomainNetbiosName = "docker",
  [string] $DomainPassword,
  [string] $DomainFunctionalLevel = "Win2012R2"
)
echo "test"
# # based on https://gist.github.com/PatrickLang/27c743782fca17b19bf94490cbb6f960 - credit Patrick Lang
# Install-WindowsFeature AD-Domain-Services
# Import-Module ADDSDeployment
# Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainNetbiosName -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode $DomainFunctionalLevel -ForestMode $DomainFunctionalLevel -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true
# # ^^ will prompt for safeadminpassword
# # This next step is bad. Don't do it in production. I'm not a Kerberos expert so I won't try to explain why
# Add-KdsRootKey –EffectiveTime ((get-date).addhours(-10))