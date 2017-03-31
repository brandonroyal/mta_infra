[CmdletBinding()]
Param(
  [switch] $SkipEngineUpgrade,
  [string] $ArtifactPath = ".",
  [string] $DockerVersion = "17.04.0-ce-rc1"
)

#Variables
$Date = Get-Date -Format "yyyy-MM-dd HHmmss"
$DockerPath = "C:\Program Files\Docker"

function UpgradeDockerEngine () {
    #Get Docker Engine from Master Builds
    if ((-not (Test-Path (Join-Path $ArtifactPath "docker.exe"))) -and (-not (Test-Path (Join-Path $ArtifactPath "dockerd.exe")))) {
        Invoke-WebRequest -Uri "https://test.docker.com/builds/Windows/x86_64/docker-$DockerVersion.zip" -OutFile (Join-Path $ArtifactPath "docker-$DockerVersion.zip")
    }

    #Get Docker Engine
    Expand-Archive -Path (Join-Path $ArtifactPath "docker-$DockerVersion.zip") -DestinationPath "$ArtifactPath" -Force

    #Replace Docker Engine
    Stop-Service docker
    Copy-Item "$ArtifactPath\docker\dockerd.exe" "$DockerPath\dockerd.exe" -Force
    Copy-Item "$ArtifactPath\docker\docker.exe" "$DockerPath\docker.exe" -Force
    Start-Service docker
}

function Enable-TestMode() {
    bcdedit -set testsigning on
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

function Enable-RemotePowershell () {
    #Enable remote powershell for remote management
    Enable-PSRemoting -Force
    Set-Item wsman:\localhost\client\trustedhosts * -Force
}

function Install-OverlayPrivatePackage() {
    # --Install new swarm/overlay package--
    .\WS2016-KB123456-x64-InstallForTestingPurposesOnly-V2.exe /q
}

#Start Script
$ErrorActionPreference = "Stop"
try
{
    Start-Transcript -path "C:\ProgramData\Docker\configure-worker $Date.log" -append
    
    if (-not ($SkipEngineUpgrade.IsPresent)) {
        Write-Host "Upgrading Docker Engine"
        UpgradeDockerEngine
    }

    Write-Host "Enabling Test Mode"
    Enable-TestMode

    Write-Host "Disabling Firewall"
    Disable-Firewall

    Write-Host "Enabling Remote Powershell"
    Enable-RemotePowershell

    Write-Host "Install Overlay Package"
    Install-OverlayPrivatePackage

    Write-Host "Restarting machine"
    Stop-Transcript
}
catch
{
    Write-Error $_
}
