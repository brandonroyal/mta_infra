# MTA POC Sample App
Demo application for Docker Datacenter Windows POC

## Download App and Extract App
```
#From Windows Server 2016 node with Docker and access to Docker Trusted Registry (DTR)
C:\> Invoke-WebRequest -Uri https://broyal.blob.core.windows.net/1eae3d83-fc8b-4eba-8702-4bb20fcd6105/demoapp.zip -OutFile demoapp.zip

C:\> Expand-Archive -Path demoapp.zip -OutputPath <source_code_path>

C:\> cd <source_code_path>
```

# Create Image Repository in Docker Trusted Registry (DTR)
1) Log into Docker Trusted Registry
2) [Create a Repository](https://docs.docker.com/datacenter/dtr/2.2/guides/user/manage-images/)

# Build Demo App Image
```
C:\> docker build -t <docker_trusted_registry_url>/<user_or_organization>/<app_name>:<app_version> .
```

# Login and Push App to Docker Trusted Registry (DTR)
```
C:\> docker login

C:\> docker push <docker_trusted_registry_url>/<user_or_organization>/<app_name>:<app_version>
```

# Deploy App
1) Login to Docker Universal Control Plane
2) Resources >> Services >> Create a Service
3) Configure Details
    * Name Service
    * Enter Image Name as "<docker_trusted_registry_url>/<user_or_organization>/<app_name>:<app_version>"
4) Configure Scheduling
    * Add Constraint "node.platform.os==windows"
5) Configure Resources
    * Add Port
        * Internal Port: `80`
        * Protocol: `tcp`
        * Publish Mode: `host`
        * Public Port: `80`
6) Deploy now!

# View App
1) Browse `wrk_pip` public IP address
2) Website should appear

# Scale App
1) Resources >> Services
2) Select service you'd like to scale
3) Scheduling >> Scale
4) Update Scale value to 3, clicking check mark to confirm
5) Save Changes