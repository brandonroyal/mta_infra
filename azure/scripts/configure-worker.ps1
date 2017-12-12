[CmdletBinding()]
Param(
    [Parameter()]
    [switch] $SkipEngineUpgrade,

    [Parameter()]
    [string] $ArtifactPath = ".",

    [Parameter(Mandatory=$true)]
    [string] $DockerVersion,

    [Parameter(Mandatory=$true)]
    [string] $UcpVersion,

    [Parameter(Mandatory=$true)]
    [string] $UcpHostname,

    [Parameter()]
    [string] $UcpUsername = "admin",

    [Parameter(Mandatory=$true)]
    [string] $UcpPassword,

    [Parameter()]
    [string] $AdminUsername,

    [Parameter(Mandatory=$true)]
    [string] $AdminPassword,

    [Parameter()]
    [string] $DnsInternalIp = "10.0.144.30",

    [Parameter()]
    [string] $UcpInternalIp = "10.0.144.5",

    [Parameter(Mandatory=$true)]
    [string] $DTRFQDN,

    [Parameter()]    
    [string] $DomainName = "docker.local"
    
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

function Install-LatestDockerEngine () {
    $dockerMajorMinorVersion = $DockerVersion.Substring(0, 5)
    Invoke-WebRequest -Uri "https://download.docker.com/components/engine/windows-server/$dockerMajorMinorVersion/docker-$DockerVersion.zip" -OutFile "docker.zip"

    Stop-Service docker
    Remove-Item -Force -Recurse $env:ProgramFiles\docker
    Expand-Archive -Path "docker.zip" -DestinationPath $env:ProgramFiles -Force
    Remove-Item docker.zip

    Start-Service docker
}

function Install-WindowsUpdates() {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module PSWindowsUpdate -Force
    # https://github.com/moby/moby/issues/34696#issuecomment-347342896
    Get-WUInstall -WindowsUpdate -KBArticleID 4051033 -AcceptAll
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
    $DownloadFileUri="https://github.com/PowerShell/Win32-OpenSSH/releases/download/v0.0.22.0/OpenSSH-Win32.zip"
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

function Set-DtrAsInsecureRegistry() {
    #only for PoC purposes to allow push/pull to DTR that uses self-signed certs
    $json = @"
    {
       "insecure-registries": [ "${DTRFQDN}" ]
    }
"@
    $json | Out-File "c:\programdata\docker\config\daemon.json" -Encoding ascii -Force
    Restart-Service docker
}

function Start-UcpNodePrep() {
    docker pull docker/ucp-dsinfo-win:$UcpVersion
    docker pull docker/ucp-agent-win:$UcpVersion

    Add-Content setup.ps1 $(docker run --rm docker/ucp-agent-win:$UcpVersion windows-script)
    & .\setup.ps1
    Remove-Item -Force setup.ps1
}



function Update-DnsConfiguration(){
    # Set DNS Servers on eth device to Domain Controller / DNS + Azure DNS (e.g. existing DNS)
    Write-Host "[INFO] Available network adapters"
    Get-NetAdapter
    # $ifIndex = (Get-NetAdapter -Name "vEthernet (HNSTransparent)").ifIndex
    $ifIndex = (Get-NetAdapter -Name Ethernet*).ifIndex
    $existingDns = (Get-DnsClientServerAddress -InterfaceIndex $ifIndex -AddressFamily ipv4).ServerAddresses
    Write-Host "[INFO] Setting DNS to $DnsInternalIp and $existingDns"
    Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $DnsInternalIp, $existingDns
}

function Test-DomainConnectivity(){
    Test-Connection $DomainName
}

function Join-Domain(){
    #troubleshooting only
    $tempPassword = "P@ssword1"
    $secureAdminPassword = ConvertTo-SecureString $tempPassword -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential ($AdminUsername, $secureAdminPassword)
    Add-Computer -DomainName $DomainName -Credential $credentials
}

function Join-SwarmNode() {
    
    add-type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
    
                public class SelfSignedAllowedPolicy : ICertificatePolicy {
                public SelfSignedAllowedPolicy() {}
                public bool CheckValidationResult(
                    ServicePoint sPoint, X509Certificate cert,
                    WebRequest wRequest, int certProb) {
                    return true;
                }
            }
"@
    
    [System.Net.ServicePointManager]::CertificatePolicy = new-object SelfSignedAllowedPolicy
    $body=@{
        'username' = $UcpUsername
        'password' = $UcpPassword
    } | ConvertTo-Json
    $auth_response = Invoke-RestMethod -Uri https://$UcpHostname/auth/login -Body $body -Method Post
    $swarm_response = Invoke-RestMethod -Uri https://$UcpHostname/swarm -Headers @{"AUTHORIZATION"="Bearer " + $auth_response.auth_token } -Method Get
    docker swarm join --token $swarm_response.JoinTokens.Worker $UcpInternalIp
}

#Start Script
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

try
{
    Start-Transcript -path "C:\ProgramData\Docker\configure-worker $Date.log" -append

    Write-Host "[INFO] Disabling Real Time Monitoring"
    Disable-RealTimeMonitoring
    
    if (-not ($SkipEngineUpgrade.IsPresent)) {
        Write-Host "[INFO] Upgrading Docker Engine"
        Install-LatestDockerEngine
    }

    Write-Host "[INFO] Setting DTR As Insecure Registry"
    Set-DtrAsInsecureRegistry

    Write-Host "[INFO] Getting UCP Images and Preparing Node"
    Start-UcpNodePrep

    Write-Host "[INFO] Disabling Firewall"
    Disable-Firewall

    Write-Host "[INFO] Installing OpenSSH"
    Install-OpenSSH

    # Write-Host "[INFO] Updating DNS Settings"
    # Update-DnsConfiguration

    Write-Host "[INFO] Testing DNS and Connectivity to Domain"
    Test-DomainConnectivity

    # Write-Host "[INFO] Joining Domain"
    # Join-Domain

    Write-Host "[INFO] Join Swarm Cluster"
    Join-SwarmNode

    Write-Host "[INFO] Script Complete. Restarting Machine"
    
    Restart-Computer -Force
}
catch
{
    Write-Error "[FATAL] Configure worker failed"
    Write-Error $_.Exception
}
finally
{
    Stop-Transcript
}
