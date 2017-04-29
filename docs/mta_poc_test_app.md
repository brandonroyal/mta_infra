# Modernize Traditional Application (MTA) POC
## *Test App Deployment*

To ensure the Docker EE has been configured properly, we can deploy a series of test applications to validate their functionality.  Below are some simple test applications to select based on your environment.

### Simple Window Auth
This application assumes the [these](https://gist.github.com/PatrickLang/27c743782fca17b19bf94490cbb6f960) steps are complete and a domain is configured, windows nodes are joined to domain, a gMSA is created for the application and a credential spec file has been created.

1) Distribute credential spec file to each host

2) Deploy Service (using host mode)
```
$ docker service create --name test --hostname app.example.com -p mode=host,target=80,published=80 --credential-spec "file://app.json" broyal/test-winauth-web:latest
```

3) Ensure conatiner hostname (in this example, `app.example.com`) resolves to the worker public IP

_NOTE: Using domain identities within application requires credential spec files to be passed into container using `--credential-spec "file://credentialspec.json"`. _

### [Optional] Test Swarm and Service Deployments

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

### [Optional] Create Overlay Network and Test Service DNS/Connectivity

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