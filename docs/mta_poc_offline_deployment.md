# DDC WS2016 POC

## Recommended Infrastructure

* 2 Linux Nodes (1 UCP manager, 1 DTR worker)
* 3 Windows Server 2016 Nodes (workers)
* 1 vNet
* [Optional] Load balancers in front of 3 Windows Server 2016 nodes

## Docker Target Software Versions

* 1 Linux node - Docker 17.03.0-ee
  * Docker Universal Control Plane (UCP) 2.2.1
* 1 Linux node - Docker 17.03.0-ee
  * Docker Trusted Registry (DTR) 2.2.3
* 3 Windows Server 2016 nodes - Docker 17.04.0-dev

## POC Architecture

![POC Architecture](https://cloud.githubusercontent.com/assets/2762697/21507592/cd8e7410-cc47-11e6-9dc8-f4244f0432f2.png)

## Preparation
For offline installation, files need to be prepared and copied to each node.
Packages have been prepared with all the necessary files for each node type:

[docker_ucp_linux_offline.tar.gz](https://broyal.blob.core.windows.net/1eae3d83-fc8b-4eba-8702-4bb20fcd6105/docker_ucp_linux_offline.tar.gz)

1) Download package from internet connected machine and copy to target Linux node

2) Extract on target Linux node
```
$ tar -xvzf docker_ucp_linux_offline.tar.gz
```
[docker_dtr_linux_offline.tar.gz](https://broyal.blob.core.windows.net/1eae3d83-fc8b-4eba-8702-4bb20fcd6105/docker_dtr_linux_offline.tar.gz)

1) Download package from internet connected machine and copy to target Linux node

2) Extract on target Linux node
```
$ tar -xvzf docker_dtr_linux_offline.tar.gz
```
[docker_wrk_win_offline](https://broyal.blob.core.windows.net/1eae3d83-fc8b-4eba-8702-4bb20fcd6105/docker_wrk_win_offline.zip)

1) Download package from internet connected machine and copy to all target Windows nodes

2) Extract on target Windows nodes

## Install Docker Engine on Linux Nodes

### RHEL

1) If not already complete, download and extract [offline package](#preparation). Change directory to `docker_ucp_linux_offline` or `docker_dtr_linux_offline` depending on role

2) Install RPM packages
```
$ sudo yum install -y docker-ee-selinux-17.03.0.ee.1-1.el7.centos.noarch.rpm
```
```
$ sudo yum install -y docker-ee-17.03.0.ee.1-1.el7.centos.x86_64.rpm
```
3) Enable docker service
```
$ sudo systemctl enable docker.service
```
4) Start docker service
```
sudo systemctl start docker
```
5) Repeat for each linux node

## Upgrade Docker and Install Overlay on Windows Nodes

1) RDP to first Windows node

2) If not already complete, download and extract `docker_wrk_win_offline` [offline package](#online-vs-offline-installation-artifacts). Change directory to `docker_wrk_win_offline`

3) Ensure `OverlayNetworkV2.zip` is downloaded from Microsoft connect and available in the current directory

4) If overylay networking components have been previously installed, follow [these steps](#uninstall-previous-versions-of-overlay-hotfixes) to remove them

5) Run `configure-worker.ps1` script (NOTE: machine will restart when script is complete)
```
C:\> ./configure-worker.ps1
```

6) Validate correct docker client and server version
```
C:\> docker version
...
Client:
 Version:      17.04.0-dev
...
Server:
 Version:      17.04.0-dev
...
```

7) Validate that overlay networking is correctly installed
```
tasklist /m overlayhnsplugin.dll
```

8) Repeat for each Windows node


## Install Universal Control Plane (UCP) on 1st Linux Node

1) SSH to node

2) Disable firewall ([Ubuntu](#ubuntu-disable-firewall), [RHEL 7](#rhel-disable-firewall))

3) Restart Docker Daemon ([RHEL 7](#rhel-7-restart-docker-daemon))

4) Unpack UCP images
```
docker load < ucp_images_2.1.0.tar.gz
```

5) run ucp install command
```
$ docker run --rm --name ucp \
  -v /var/run/docker.sock:/var/run/docker.sock \
   docker/ucp:2.1.1 \
   install --enable-windows --host-address <UCP_HOST_ADDRESS> --san <UCP_PUBLIC_FQDN> --admin-password <UCP_ADMIN_PASSWORD>
```
***UCP_HOST_ADDRESS:*** *ip address of secondary NIC where UCP/Swarm will advertise manager*

***UCP_PUBLIC_FQDN:*** *fully qualified domain name by which UCP UI will be accessed (e.g. ucp.internal.domain.com)*

***UCP_ADMIN_PASSWORD:*** *password for UCP admin account*


5) Log into UCP UI at <ucp_url> above

![](https://cloud.githubusercontent.com/assets/2762697/21510171/454e72f0-cc5e-11e6-8ffe-84d56ee86e30.png)

## Join Windows Nodes to UCP Swarm

1) While logged into UCP UI, select Resources >> Nodes >> Add Node

![](https://cloud.githubusercontent.com/assets/2762697/21510204/c675a9de-cc5e-11e6-9c84-2ddaa1464c20.png)

2) Copy join command

3) RDP to 1st Windows node

4) Load `docker/ucp-agent-win` image
```
C:\> docker load -i .\ucp_images_win_2.1.1.tar.gz
```
5) Run join command from step #2

6) Run postjoin-worker.ps1 script
```
C:\> .\postjoin-worker.ps1
```

7) Repeat 2-6 for each Windows worker node

## Test Swarm and Service Deployments

1) SSH to Linux manager

2) Validate all nodes are active
```
$ docker node ls
...
tb7edpogha8l2tx4c22lrropd *  broyal-mgr0  Ready   Active        Leader
virfawpbdl7pa1ren9yvw3m6m    broyal-wrk1  Ready   Active
w9ibbpk9d8z20d47fva84g85n    broyal-wrk2  Ready   Active
asdekd9d8z20d47f8djsjdfk8    broyal-wrk3  Ready   Active
```
3) Deploy a test service
```
$ docker service create --name s0 --constraint node.platform.os==windows microsoft/windowsservercore ping -t localhost
```
4) Check that service is running
```
$ docker service ps s0
...
ID            NAME      IMAGE                               NODE                       DESIRED STATE  CURRENT STATE              ERROR                             PORTS
40f71ye2hcjm  s0.1      microsoft/windowsservercore:latest  broyal-wrk1                Running        Running about an hour ago
```
5) Create IIS service with exposed ports
```
$ docker service create --name s1 --port mode=host,target=80,published=80 --constraint node.platform.os==windows microsoft/iis
```
6) Check that service and running.  Note the worker node
```
$ docker service ps s1
```
7) Browse to load balancer or worker address at :80. You should see an IIS welcome screen

8) Cleanup test services
```
$ docker service rm s0
$ docker service rm s1
```

## Create Overlay Network and Test Service DNS/Connectivity

1) SSH to Linux manager

2) Create overlay network
```
$ docker network create overlaynet --driver overlay
```

3) Create first service attached to overlay network
```
$ docker service create --name s0 --network overlaynet --endpoint-mode dnsrr --constraint node.platform.os==windows microsoft/windowsservercore
```

4) Create second service attached to overlay network
```
$ docker service create --name s1 --network overlaynet --endpoint-mode dnsrr --constraint node.platform.os==windows microsoft/windowsservercore
```

5) Validate that both services are running (e.g. both 1/1)
```
$ docker service ls
```

6) Get node for service s1
```
$ docker service ps s1
```

7) RDP to worker where s1 is deployed
8) Copy s1 container id
```
C:\> docker ps
```
9) Execute interactive commands within container
```
C:\> docker exec -it <s1_container_id> powershell
```
10) Check that s0 resolves and responds to ping request
```
C:\> ping s0
...
//TODO: ping response output
```

## Install Docker Trusted Registry (DTR)

1) SSH to DTR node

2) Load UCP images
```
$ docker load < ucp_images_2.1.1.tar.gz
```

3) Log into UCP UI at <ucp_url> above

![](https://cloud.githubusercontent.com/assets/2762697/21510171/454e72f0-cc5e-11e6-8ffe-84d56ee86e30.png)

4) While logged into UCP UI, select Resources >> Nodes >> Add Node

![](https://cloud.githubusercontent.com/assets/2762697/21510204/c675a9de-cc5e-11e6-9c84-2ddaa1464c20.png)

5) Copy join command

6) Paste and run join command from #5

7) Load DTR images
```
$ docker load < dtr-2.2.3.tar.gz
```

8) Get HOSTNAME of UCP node and note for next step
```
$ docker node ls
...
ID                           HOSTNAME     STATUS  AVAILABILITY  MANAGER STATUS
tb7edpogha8l2tx4c22lrropd *  broyal-mgr0  Ready   Active        Leader
```

9) Install DTR
```
docker run --rm \
  docker/dtr:2.2.3 install \
  --ucp-url https://<UCP_PUBLIC_FQDN> --ucp-node <UCP_NODE> --dtr-external-url https://<DTR_PUBLIC_FQDN> --ucp-username admin --ucp-password <UCP_ADMIN_PASSWORD> --ucp-insecure-tls
```

***UCP_PUBLIC_FQDN:*** *fully qualified domain name by which UCP UI will be accessed (e.g. ucp.internal.domain.com)*

***UCP_NODE:*** *HOSTNAME from step #9*

***DTR_PUBLIC_FQDN:*** *fully qualified domain name by which DTR UI will be accessed (e.g. dtr.internal.domain.com)*

***UCP_ADMIN_PASSWORD:*** *UCP admin password used when installing UCP*


## Appendix

### Uninstall previous versions of overlay hotfixes

1) Open an elevated PowerShell session.

2) Stop the Docker and HNS services; run:
```
    stop-service hns
		stop-service docker
```

3) Run the following PowerShell commands to check for and remove any previous versions of the overlay package that may be on your machine. If a package exists, you will be prompted to confirm removal of the package. If/when you are prompted, select "yes".
```
  if (Get-HotFix | where HotfixID -match "KB888882") {wusa /uninstall /kb:888882 /norestart;}
  if (Get-HotFix | where HotfixID -match "KB123456") {wusa /uninstall /kb:123456 /norestart;}
```

### Firewall

#### RHEL Disable firewall
```
sudo systemctl stop firewalld
```

#### Ubuntu Disable firewall
```
sudo ufw disable
```

### Docker Daemon

#### RHEL 7 restart docker daemon
```
sudo systemctl restart docker
```

#### Ubuntu restart docker daemon
```
sudo service docker restart
```