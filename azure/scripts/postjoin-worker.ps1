[CmdletBinding()]
Param(

)

function Test-DockerUcpPathExists() {
    if (!(Test-Path c:\ProgramData\docker\ucp\))
    {
        ThrowError "UCP cert path does not exist"
    }
}

function Stop-Docker() {
    Stop-Service docker
}

function Register-DockerService() {
    dockerd --unregister-service
    dockerd -H npipe:// -H 0.0.0.0:12376 --tlsverify --tlscacert=c:\ProgramData\docker\ucp\ca.pem --tlscert=c:\ProgramData\docker\ucp\cert.pem --tlskey=c:\ProgramData\docker\ucp\key.pem --register-service
}

function Start-Docker() {
    Start-Service docker
}

#Start Script
$ErrorActionPreference = "Stop"
try 
{
    Write-Host "Checking UCP Cert path"
    Test-DockerUcpPathExists

    Write-Host "Stopping Docker Service"
    Stop-Docker

    Write-Host "Re-registering Docker Service"     
    Register-DockerService

    Write-Host "Starting Docker Service"
    Start-Docker
}
catch
{
    Write-Error $_
}



