# MTA PoC Infrastructure

Infrastructure setup for MTA PoC environments

## Usage

This template currently deploys a UCP manager, a single DTR replica and UCP workers (Windows Server 2016)

### Deploy - Bash

Deploy Docker EE to Azure using interactive deployment script

#### 1. Download deployment script

```bash
wget https://raw.githubusercontent.com/BrandonRoyal/mta_infra/master/deploy.sh
```

#### 2. Login to Azure CLI (Optional if not already logged in)

```bash
az login
```

#### 3. Deploy using script

**[Optional]** Set environment variables to prepopulate variables in the deployment script

```bash
export AZURE_RESOURCE_GROUP_NAME=<azure _resource_group_name>
export AZURE_LOCATION=<azure_location>
export AZURE_ITEM_PREFIX=<azure_item_prefix>
export AZURE_DOCKER_ADMIN_PASSWORD=<azure_docker_admin_password>
export SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)
```

```bash
sh deploy.sh
```

**_Note the hostnames returned when script is complete_**

#### 4. Join nodes to domain

Use SSH (or Remote Desktop Client) to connect to Windows Worker.  Note that each ports are used to access the appropriate worker host

| worker | hostname | port (SSH) | port (RDP) |
|---|---|---|---|
| *-wrk0 | `<wrk-hostname>` | 50020 | 50000 |
| *-wrk1 | `<wrk-hostname>` | 50021 | 50001 |
| *-wrk2 | `<wrk-hostname>` | 50022 | 50002 |

```bash
ssh -p 50020 docker@<wrk-hostname>
```

Open PowerShell

```cmd
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe
```

Join node to domain

```powershell
$password = Read-Host "Admin password: " -AsSecureString
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
$password = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ('docker', $password)
Add-Computer -DomainName 'docker.local' -Credential $credentials
Restart-Computer -Force
```

Repeat for each worker node

#### 5. Complete Active Directory Controller Configuration

Use SSH (or Remote Desktop Client) to connect to AD Domain Controller

```bash
ssh docker@<ad-server-hostname>
```

Open PowerShell

```cmd
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe
```

Run configuration script to complete AD controller setup

```powershell
cd C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9\Downloads\0
.\configure-ad.ps1 -MachinePrefix <azure_item_prefix>
```

NOTE: This script creates the following in AD

* group for all container hosts - `containerhosts`
* group managed service accounts for test app - `app1.docker.local`
* test user - `user1`
* group for authorized users of test app - `app1 authorized users`

#### 6. Create Credential Spec on each host

Use SSH (or Remote Desktop Client) to connect to Windows Worker.

```bash
ssh -p 50020 docker@<ad-server-hostname>
```

Open PowerShell

```cmd
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe
```

Create CredentialSpec for `app1.docker.local`

```powershell
Start-BitsTransfer https://raw.githubusercontent.com/Microsoft/Virtualization-Documentation/live/windows-server-container-tools/ServiceAccounts/CredentialSpec.psm1
Import-Module ./CredentialSpec.psm1
Import-Module .\CredentialSpec.psm1
New-CredentialSpec -Name app1 -AccountName app1
```

Deploy test container

```powershell
docker run -it --security-opt "credentialspec=file://app1.json" microsoft/windowsservercore cmd
```

Repeat for each of three workers

## Contributing

To develop the template locally, use the DEBUG=true environment variable.  This points to the local azuredeploy.json file (azure/ee-windows/azuredeploy.json)

### Prerequisites

When running in `DEBUG` mode, the script will temporarily upload script files to a private gist, allowing you to test incremental changes before committing them to the repo

* [gist CLI](https://github.com/defunkt/gist)

### Deploying in Debug Mode - Bash

1. Set debug variable

```bash
export DEBUG=true
```

1. Login to Azure CLI (Optional if not already logged in)

```bash
az login
```

1. Login to GitHub Gist (Optional if not already logged in)

```bash
gist --login
```

1. Deploy using script

```bash
sh deploy.sh
```

### Known Issues

1. gist -pR returns null when too ~10+ files are uploaded at any one time. Only relevent for DEBUG configuration since that's the only place where gist is used.