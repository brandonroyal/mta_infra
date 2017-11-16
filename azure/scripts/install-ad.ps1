[CmdletBinding()]
Param(
  [string] $DomainName = "docker.local",
  [string] $DomainNetbiosName = "docker",
  [string] $DomainPassword,
  [string] $DomainFunctionalLevel = "Win2012R2"
)

#Variables
$Date = Get-Date -Format "yyyy-MM-dd HHmmss"

function Install-OpenSSH () {
  $DownloadFileUri="https://github.com/PowerShell/Win32-OpenSSH/releases/download/v0.0.22.0/OpenSSH-Win32.zip"
  $ProgramFilesPath="C:\Program Files\"
  $SSHProgramPath=$(Join-Path $ProgramFilesPath "OpenSSH-Win32")
  
  Invoke-WebRequest -UseBasicParsing -Uri $DownloadFileUri -OutFile OpenSSH-Win32.zip
  
  Expand-Archive -Path .\OpenSSH-Win32.zip -DestinationPath $ProgramFilesPath
  
  Set-Location $SSHProgramPath
  PowerShell -ExecutionPolicy Bypass -File install-sshd.ps1
  .\ssh-keygen.exe -A
  .\FixHostFilePermissions.ps1 -Confirm:$false
  New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH
  Set-Service sshd -StartupType Automatic
  Set-Service ssh-agent -StartupType Automatic
  Start-Service sshd
}

function Install-ADDomainController {
  # ----
  # based on https://gist.github.com/PatrickLang/27c743782fca17b19bf94490cbb6f960 - credit Patrick Lang
  # ----

  # Install AD Services
  Write-Host "[INFO] Installing AD Domain Services"
  Install-WindowsFeature AD-Domain-Services
  # Install AD Admin Center
  Write-Host "[INFO] Install AD Admin Center"
  Install-WindowsFeature RSAT-AD-AdminCenter
  # Import AD Domain Service Deployment module
  Write-Host "[INFO] Opening port 9389 in the Windows firewall for inbound and outbound traffic";
  netsh advfirewall firewall add rule name="psad_9389_in" dir=in action=allow protocol=TCP localport=9389 | Out-Null;
  netsh advfirewall firewall add rule name="psad_9389_out" dir=out action=allow protocol=TCP localport=9389 | Out-Null;
  
  Import-Module ADDSDeployment
  # Convert to secure password
  $DomainPasswordSecure = $(ConvertTo-SecureString -AsPlainText $DomainPassword -Force)
  # Configure Domain Forest
  Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainNetbiosName -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode $DomainFunctionalLevel -ForestMode $DomainFunctionalLevel -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -SafeModeAdministratorPassword $DomainPasswordSecure -Force:$true
  # Machine Restart
}

try
{
  Start-Transcript -path "C:\install-ad_$Date.log" -append

  Write-Host "[INFO] Install OpenSSH"
  Install-OpenSSH

  Write-Host "[INFO] Install AD Domain Controller"
  Install-ADDomainController

  Stop-Transcript
}
catch
{
  Write-Error $_
}