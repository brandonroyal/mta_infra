[CmdletBinding()]
Param(
    $ArtifactPath = "."
)

function Add-ContainersFeature () {
    If (-Not (Get-Service -display "Containers" -ErrorAction SilentlyContinue)){
        Write-Host "Windows Server Docker Installer :" $Name "is not installed on this computer. Installing..."
        Install-WindowsFeature Containers
    } Else {
        Write-Host "Windows Server Docker Installer : " $Name " is installed."
    }
}

function Copy-DockerArtifacrts () {
    New-Item (Join-Path $env:ProgramFiles "Docker") -ItemType Directory
    Copy-Item -Path (Join-Path $ArtifactPath "docker.exe") -Destination (Join-Path $env:ProgramFiles "Docker")
    Copy-Item -Path (Join-Path $ArtifactPath "dockerd.exe") -Destination (Join-Path $env:ProgramFiles "Docker")
}

function Register-DockerPath () {
    $env:path += ";c:\program files\docker"
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Docker", [EnvironmentVariableTarget]::Machine)
}

function Register-DockerService () {
    dockerd --register-service
}

try {
    Write-Host "Adding Container Features"
    Add-ContainersFeature

    Write-Host "Copying Docker Artifacts"
    Copy-DockerArtifacrts

    Write-Host "Registering Docker Path"
    Register-DockerPath

    Write-Host "Registering Docker Service"
    Register-DockerService
}
catch [System.Exception] {
    Write-Error $_
}