[CmdletBinding()]
param (
    [string] $DockerDataPath = "C:\ProgramData\docker",
    [Parameter(Mandatory=$true)]
    [string] $JoinToken,
    [string] $UcpManagerIp = "10.0.144.5"
)

function removeFromManagerWarning(){
    Write-Host "Have you removed this node from the UCP Manager? (y/n)"
    $response = Read-Host
    if (!($response -ceq "y")){
        Write-Host "Exiting script"
        exit
    }
}

function removeFromSwarm(){
    Write-Host "Leaving Swarm"
    docker swarm leave
}

function deleteUcpCerts(){
    if (Test-Path (Join-Path $DockerDataPath "ucp")){
        Write-Host "Removing UCP Certs"
        rm -r (Join-Path $DockerDataPath "ucp")
    }
}

function joinSwarm(){
    docker swarm join --token $JoinToken $UcpManagerIp`:2377
}

function Test-DockerUcpPathExists() {
    DO
    {
        Write-Host "Waiting 10s for UCP Certs"
        Start-Sleep -s 10
    }
    Until (Test-Path (Join-Path $DockerDataPath "ucp"))
}


function Register-DockerService() {
    dockerd --unregister-service
    $DTR_FQDN = Get-Content (Join-Path $DockerDataPath "dtr_fqdn")
    if (-not $DTR_FQDN) {
        dockerd -H npipe:// -H 0.0.0.0:12376 --tlsverify --tlscacert=c:\ProgramData\docker\ucp\ca.pem --tlscert=c:\ProgramData\docker\ucp\cert.pem --tlskey=c:\ProgramData\docker\ucp\key.pem --register-service
    } else {
        dockerd -H npipe:// -H 0.0.0.0:12376 --tlsverify --tlscacert=c:\ProgramData\docker\ucp\ca.pem --tlscert=c:\ProgramData\docker\ucp\cert.pem --tlskey=c:\ProgramData\docker\ucp\key.pem --register-service --insecure-registry $DTR_FQDN
    }
}

removeFromManagerWarning
removeFromSwarm
deleteUcpCerts
joinSwarm
Test-DockerUcpPathExists
Register-DockerService
Write-Host "Re-register complete.  Registration takes a few minutes to register in UCP UI"