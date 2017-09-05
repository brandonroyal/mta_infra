[CmdletBinding()]
Param(
  [switch] $SkipEngineUpgrade,
  [string] $ArtifactPath = ".",
  [string] $DockerVersion = "17.06.1-ee-1",
  [string] $UcpVersion,
  [string] $DTRFQDN
)

#Variables
$Date = Get-Date -Format "yyyy-MM-dd HHmmss"
$DockerPath = "C:\Program Files\Docker"
$DockerDataPath = "C:\ProgramData\Docker"

function Disable-RealTimeMonitoring () {
    Set-MpPreference -DisableRealtimeMonitoring $true
}

function Disable-WindowsUpdates() {
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 1 /f
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
}

function Install-LatestDockerEngine () {
    $dockerMajorMinorVersion = $DockerVersion.Substring(0, 5)
    Invoke-WebRequest -Uri "https://download.docker.com/components/engine/windows-server/$dockerMajorMinorVersion/docker-$DockerVersion.zip" -OutFile "docker.zip"

    Stop-Service docker
    Remove-Item -Force -Recurse $env:ProgramFiles\docker
    Expand-Archive -Path "docker.zip" -DestinationPath $env:ProgramFiles -Force
    Remove-Item docker.zip

    Start-Service docker
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
    $DownloadFileUri="https://github.com/PowerShell/Win32-OpenSSH/releases/download/v0.0.18.0/OpenSSH-Win32.zip"
    $ProgramFilesPath="C:\Program Files\"
    $SSHProgramPath=$(Join-Path $ProgramFilesPath "OpenSSH-Win32")
    
    Invoke-WebRequest -UseBasicParsing -Uri $DownloadFileUri -OutFile OpenSSH-Win32.zip
    
    Expand-Archive -Path .\OpenSSH-Win32.zip -DestinationPath $ProgramFilesPath
    
    cd $SSHProgramPath
    PowerShell -ExecutionPolicy Bypass -File install-sshd.ps1
    .\ssh-keygen.exe -A
    .\FixHostFilePermissions.ps1 -Confirm:$false
    New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH
    Set-Service sshd -StartupType Automatic
    Set-Service ssh-agent -StartupType Automatic
    Start-Service sshd
}

function Set-DtrHostnameEnvironmentVariable() {
    $DTRFQDN | Out-File (Join-Path $DockerDataPath "dtr_fqdn")
}

function Get-UcpImages() {
    docker pull docker/ucp-dsinfo-win:$UcpVersion
    docker pull docker/ucp-agent-win:$UcpVersion

    Add-Content setup.ps1 $(docker run --rm docker/ucp-agent-win:$UcpVersion windows-script)
    & .\setup.ps1
    Remove-Item -Force setup.ps1
}

#Start Script
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

try
{
    Start-Transcript -path "C:\ProgramData\Docker\configure-worker $Date.log" -append

    Write-Host "Disabling Real Time Monitoring"
    Disable-RealTimeMonitoring
    
    if (-not ($SkipEngineUpgrade.IsPresent)) {
        Write-Host "Upgrading Docker Engine"
        Install-LatestDockerEngine
    }

    Write-Host "Getting UCP Images"
    Get-UcpImages

    Write-Host "Disabling Firewall"
    Disable-Firewall

    Write-Host "Installing OpenSSH"
    Install-OpenSSH

    Write-Host "Set DTR FQDN Environment Variable"
    Set-DtrHostnameEnvironmentVariable

    Write-Host "Restarting machine"
    Stop-Transcript
}
catch
{
    Write-Error $_
}
