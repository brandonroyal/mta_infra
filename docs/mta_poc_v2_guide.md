# Modernize Traditional Application (MTA) POC v2.0 - Deployment Guide
The following instructions walk through deployment and configuration of Docker Datacenter for Windows Server 2016 on Microsoft Azure. 

# Prerequisites

* Microsoft Azure Subscription
* [Azure CLI 2.0 (Preview)](https://docs.microsoft.com/en-us/cli/azure/install-az-cli2)
* SSH Client
* SSH RSA Key

# Installation
While the instructions are generally consistent between Windows and OSX/Linux clients, it's worth noting that some steps specify `# Windows Client` and `# OSX/Linux Client` commands. Please use the command most appropriate for your client.

## Login to Azure Account using Azure CLI
```
az login
```

## Set Variables
```
# Windows Client
$resource_group_name="<resource_group_name>" #Azure Resource Group name
$location="<location>" #Azure Location (e.g. westus)
$prefix="<prefix>" #Prefix used in naming Azure components (NOTE: Only letters and numbers, no special characters, 7 or less characters)
$adminPassword="<adminPassword>" #Admin password for VMs and Docker Datacenter admin accounts (NOTE: Must be complex and more than 8 characters. Do not use "$" or ";" characters)
$sshPublicKey="<sshPublicKey>" #SSH rsa public key (used to access Linux manager node)

# OSX/Linux Client
export resource_group_name=<resource_group_name> #Azure Resource Group name
export location=<location> #Azure Location (e.g. westus)
```
## Configure Parameters
```
# Windows Client
$parameters="
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
export parameters="
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

## Create Azure Resource Group
```
az group create --name $resource_group_name --location $location
```

## Deploy using template
```
$ az group deployment create --template-uri https://mtapoc.blob.core.windows.net/v201/azuredeploy.json --parameters @azuredeploy.parameters.json -g $resource_group_name --verbose
```
_NOTE: Deployment process takes ~10-15 minutes to complete.  You can check your deployment process at [portal.azure.com](https://portal.azure.com)_

# Configuration

## Access Docker Universal Control Plane (UCP) Web Interface
When deployment is complete, copy the parameter output `mgr_dtr_hostname` value and paste it into your preferred web browser, being sure to prepend with `https://`

![image](https://cloud.githubusercontent.com/assets/2762697/23345736/b698769a-fc47-11e6-8e28-3b2053780ce0.png)

To login, use *username:* `admin` and *password:* `<adminPassword>` you specified in your `azuredeploy.parameters.json` file from the previous step

## Join Windows Nodes to UCP Swarm

1) While logged into UCP UI, select Resources >> Nodes >> Add Node

![image](https://cloud.githubusercontent.com/assets/2762697/23345641/74cc8946-fc46-11e6-9812-1abf0e11dcd7.png)

2) Copy join command to clipboard

3) Connect to 1st Windows node (RDP)

4) Navigate to package location
```
cd C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\Downloads\0
```

5) Run join command from step #2

_NOTE: Expect a minor RDP connection interuption when node is being joined_

6) In UCP UI, wait for node to appear in node list and to display the following message:

`You must now reconfigure your windows worker node following instructions at https://www.docker.com/ddc-win-ea`

7) Run postjoin-worker.ps1 script
```
.\postjoin-worker.ps1
```

8) Get latest `microsoft/windowsservercore` and `microsoft/iis` images
```
docker pull microsoft/windowsservercore:latest
docker pull microsoft/iis:latest
```

8) Repeat 2-8 for each Windows worker node

# Testing and Validation

## Test Swarm and Service Deployments

1) SSH to Linux manager

2) Validate all nodes are active
```
docker node ls
```
3) Deploy a test service
```
docker service create --name s0 --constraint node.platform.os==windows microsoft/windowsservercore:latest ping -t localhost
```
4) Check that service is running
```
docker service ps s0
  ...
  ID            NAME      IMAGE                               NODE                       DESIRED STATE  CURRENT STATE              ERROR                             PORTS
  40f71ye2hcjm  s0.1      microsoft/windowsservercore:latest  broyal-wrk1                Running        Running about an hour ago
```
5) Create IIS service with exposed ports
```
docker service create --name s1 -p mode=host,target=80,published=80 --constraint node.platform.os==windows microsoft/iis
```
6) Check that service and running.  Note the worker node
```
docker service ps s1
```
7) Browse to load balancer or worker address at :80. You should see an IIS welcome screen

8) Cleanup test services
```
docker service rm s0
docker service rm s1
```

## Create Overlay Network and Test Service DNS/Connectivity

1) SSH to Linux manager

2) Create overlay network
```
docker network create overlaynet --driver overlay
```

3) Create first service attached to overlay network
```
docker service create --name s0 --network overlaynet --endpoint-mode dnsrr --constraint node.platform.os==windows microsoft/windowsservercore ping -t localhost
```

4) Create second service attached to overlay network
```
docker service create --name s1 --network overlaynet --endpoint-mode dnsrr --constraint node.platform.os==windows microsoft/windowsservercore ping -t localhost
```

5) Validate that both services are running (e.g. both 1/1)
```
docker service ls
```

6) Get node for service s1
```
docker service ps s1
```

7) RDP to worker where s1 is deployed
8) Copy s1 container id
```
docker ps
```
9) Execute interactive commands within container
```
docker exec -it <s1_container_id> powershell
```
10) Check that s0 resolves and responds to ping request
```
ping s0
  ...
  Pinging s0 [10.0.0.2] with 32 bytes of data:
  Reply from 10.0.0.2: bytes=32 time=2ms TTL=128
  Reply from 10.0.0.2: bytes=32 time<1ms TTL=128
  Reply from 10.0.0.2: bytes=32 time<1ms TTL=128
  Reply from 10.0.0.2: bytes=32 time<1ms TTL=128

  Ping statistics for 10.0.0.2:
      Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
  Approximate round trip times in milli-seconds:
      Minimum = 0ms, Maximum = 2ms, Average = 0ms
```