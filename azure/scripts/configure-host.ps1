[CmdletBinding()]
Param(
    [Parameter()]    
    [string] $OpenSSHVersion = "0.0.22.0"
)

#Variables
$Date = Get-Date -Format "yyyy-MM-dd HHmmss"

function Disable-RealTimeMonitoring () {
    Set-MpPreference -DisableRealtimeMonitoring $true
}

function Disable-WindowsUpdates() {
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 1 /f
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
}

function Disable-Firewall () {
    #Disable firewall (temporary)
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

    #Ensure public profile is disabled (solves public profile not persisting issue)
    $data = netsh advfirewall show publicprofile
    $data = $data[3]
    if ($data -Match "ON"){
        Set-NetFirewallProfile -Profile Public -Enabled False
    }

}

function Install-OpenSSH () {
    $DownloadFileUri="https://github.com/PowerShell/Win32-OpenSSH/releases/download/v{0}/OpenSSH-Win32.zip" -F $OpenSSHVersion
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

#Start Script
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

try
{
    Start-Transcript -path "C:\configure-host $Date.log" -append

    Write-Host "[INFO] Disabling Real Time Monitoring"
    Disable-RealTimeMonitoring

    Write-Host "[INFO] Disabling Windows Updates"
    Disable-WindowsUpdates

    Write-Host "[INFO] Disabling Firewall"
    Disable-Firewall

    Write-Host "[INFO] Installing OpenSSH"
    Install-OpenSSH
}
catch
{
    Write-Error "[FATAL] Configure worker failed"
    Write-Error $_.Exception
}
finally
{
    Write-Host "[INFO] Host configuration complete"
    Stop-Transcript
}
