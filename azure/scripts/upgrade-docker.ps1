$TempPath = "C:\Windows\Temp";
$DockerPath = "C:\Program Files\Docker";

#Get Docker Engine from Master Builds
Invoke-WebRequest -Uri "https://master.dockerproject.org/windows/amd64/docker.exe" -OutFile (Join-Path $TempPath "docker.exe")
Invoke-WebRequest -Uri "https://master.dockerproject.org/windows/amd64/dockerd.exe" -OutFile (Join-Path $TempPath "dockerd.exe")

#Replace Docker Engine
Stop-Service Docker
Copy-Item "$TempPath\dockerd.exe" "$DockerPath\dockerd.exe" -Force
Copy-Item "$TempPath\docker.exe" "$DockerPath\docker.exe" -Force

#Start Docker Engine
Start-Service Docker