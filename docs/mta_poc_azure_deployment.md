# Modernize Traditional Application (MTA) POC
## *Azure Infrastructure Deployment*

The Modernizing Traditional Applications (MTA) program is designed demonstrate the value of containerizing select, traditional applications and managing them using modern infrastructure, Docker Enterprise Edition (EE) Advanced.

The following instructions walk through deployment and configuration of Docker EE Adv. for Windows Server 2016 on Microsoft Azure. When complete, you will have a fully functional 4 node cluster. For specific apps, there may be additional requirements to add nodes to support backend databases and domains.

## Baseline Architecture
![mta infra](https://cloud.githubusercontent.com/assets/2762697/25399047/f47489c6-29a2-11e7-8b5f-e37927ec5c22.png)

## Prerequisites
* Docker Enterprise Edition Advanced License
* Microsoft Azure Subscription
* [Azure CLI 2.0 (Preview)](https://docs.microsoft.com/en-us/cli/azure/install-az-cli2)
* SSH Client
* SSH RSA Key

## Installation
While the instructions are generally consistent between Windows and OSX/Linux clients, it's worth noting that some steps specify `# Windows Client` and `# OSX/Linux Client` commands. Please use the command most appropriate for your client.  We'll be using the latest Azure CLI to create infrastructure using an Azure Resource Manager (ARM) template. This template should `only be used for POC purposes`.  For more inforation on deploying Docker containers to Azure, see [Docker for Azure](https://docs.docker.com/docker-for-azure/)

### Login to Azure Account using Azure CLI
```
$ az login
```

### Set Variables
Set the variables we'll use in the installation process. Depending on your client, issue the appropriate `# Windows Client` or `# OSX/Linux Client` commands
```
# Windows Client
# --------------

#Azure Resource Group name
> $resource_group_name="<resource_group_name>"

#Azure Location (e.g. westus)
> $location="<location>" 

#Prefix used in naming Azure components (NOTE: Only letters and numbers, no special characters, 7 or less characters)
> $prefix="<prefix>" 

#Admin password for VMs and Docker Datacenter admin accounts (NOTE: Must be more than 8 characters and include at least 1 of the following characters [1-9, a-z, A-Z, @])
> $adminPassword="<adminPassword>"

#SSH rsa public key (used to access Linux manager node)
> $sshPublicKey="<sshPublicKey>"

# OSX/Linux Client
# ----------------

#Azure Resource Group name
$ export resource_group_name=<resource_group_name>

#Azure Location (e.g. westus)
$ export location=<location>

#Prefix used in naming Azure components (NOTE: Only letters and numbers, no special characters, 7 or less characters)
$ export prefix="<prefix>"

#Admin password for VMs and Docker Datacenter admin accounts (NOTE: Must be more than 8 characters and include at least 1 of the following characters [1-9, a-z, A-Z, @])
$ export adminPassword="<adminPassword>"

#SSH rsa public key (used to access Linux manager node)(i.e. `cat ~/.ssh/id_rsa.pub`)
$ export sshPublicKey="<sshPublicKey>" 
```
### Configure Parameters
Create parameters object to pass into deployment
```
# Windows Client
> $parameters="
{
    \"prefix\": {
        \"value\": \""$prefix"\"
    },
    \"adminUsername\": {
        \"value\": \"docker\"
    },
    \"adminPassword\": {
        \"value\": \""$adminPassword"\"
    },
    \"sshPublicKey\": {
        \"value\": \""$sshPublicKey"\"
    }
}
"

# OSX/Linux Client
$ export parameters="
{
    \"prefix\": {
        \"value\": \""$prefix"\"
    },
    \"adminUsername\": {
        \"value\": \"docker\"
    },
    \"adminPassword\": {
        \"value\": \""$adminPassword"\"
    },
    \"sshPublicKey\": {
        \"value\": \""$sshPublicKey"\"
    }
}
"
```

### Create Azure Resource Group
```
$ az group create --name $resource_group_name --location $location
```

### Deploy using template
```
$ az group deployment create --template-uri https://mtapoc.blob.core.windows.net/v201/azuredeploy.json --parameters "$parameters" -g $resource_group_name --verbose
```
_NOTE: Deployment process takes ~30-35 minutes to complete including Windows Updates.  You can check your deployment process at [portal.azure.com](https://portal.azure.com)_

## Configuration
Now that the deployment has completed, we need to perform some additional steps to complete the installation.  These include:

* Joining 3 Windows nodes to Docker Swarm cluster
* Enabling Http Routing Mesh (HRM) for easy application routing
* Deploying Test Service

### Retrieving Deployment Configurations
To complete the installation, it's necessary to retrieve information about your deployment once it's complete.  You can access this information from the CLI or the [Azure Portal](https://portal.azure.com)

```
#UCP URL and IP Address
$ az network public-ip list -g $resource_group_name --query "[?contains(name,'_mgr_ucp')].{fqdn: dnsSettings.fqdn, ip: ipAddress}" -o table

#DTR URL and IP Address
$ az network public-ip list -g $resource_group_name --query "[?contains(name,'_mgr_dtr')].{fqdn: dnsSettings.fqdn, ip: ipAddress}" -o table

#App URL and IP Address
$ az network public-ip list -g $resource_group_name --query "[?contains(name,'_mgr_app')].{fqdn: dnsSettings.fqdn, ip: ipAddress}" -o table

#Worker IP Address
$ az network public-ip list -g $resource_group_name --query "[?contains(name,'_wrk')].{ip: ipAddress}" -o table
```

### Access Docker Universal Control Plane (UCP) Web Interface
Using the configuration above, navigate to `https://<UCP URL>`

![image](https://cloud.githubusercontent.com/assets/2762697/23345736/b698769a-fc47-11e6-8e28-3b2053780ce0.png)

To login, use *username:* `admin` and *password:* `<adminPassword>` you specified in your deployment parameters

### Join Windows Nodes to UCP Swarm

1) While logged into UCP UI, Add Node (Resources >> Nodes >> Add Node)

![image](https://cloud.githubusercontent.com/assets/2762697/23345641/74cc8946-fc46-11e6-9812-1abf0e11dcd7.png)

2) Copy join command to clipboard

3) Connect to 1st Windows node (RDP)

4) Navigate to package location
```
> cd C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\Downloads\0
```

5) Run join command from step #2

_NOTE: Expect a minor RDP connection interuption when node is being joined_

6) In UCP UI, wait for node to appear in node list and to display the following message:

`You must now reconfigure your windows worker node following instructions at https://www.docker.com/ddc-win-ea`

7) Run postjoin-worker.ps1 script
```
> .\postjoin-worker.ps1
```

8) Get latest `microsoft/windowsservercore` and `microsoft/iis` images
```
> docker pull microsoft/windowsservercore:latest
> docker pull microsoft/iis:latest
```

8) Repeat 2-8 for each Windows worker node

### [Optional] Enable Http Routing Mesh

1) SSH to Linux manager

2) Create HRM network
```
$ docker network create --label com.docker.ucp.mesh.http=true --driver overlay ucp-hrm
```

3) In UCP UI, enable HTTP Routing Mesh (Admin Settings >> Routing Mesh)

![image](https://cloud.githubusercontent.com/assets/2762697/25358303/ce1c037e-28f5-11e7-95da-e22f0921df68.png)

### [Optional] Configure Active Directory

https://gist.github.com/PatrickLang/27c743782fca17b19bf94490cbb6f960