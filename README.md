# MTA PoC Infrastructure
Infrastructure setup for MTA PoC environments

## Usage
This template currently deploys a UCP manager, a single DTR replica and UCP workers (Windows Server 2016)

### Deploy - Bash
Deploy Docker EE to Azure using interactive deployment script

1. Download deployment script
```
$ wget https://raw.githubusercontent.com/BrandonRoyal/mta_infra/master/deploy.sh
```
2. Login to Azure CLI (Optional if not already logged in)
```
$ az login
```
3. Deploy using script
```
$ sh deploy.sh
```

**[Optional]** Set environment variables to prepopulate variables in the deployment script
```
$ export AZURE_RESOURCE_GROUP_NAME=<azure _resource_group_name>
$ export AZURE_LOCATION=<azure_location>
$ export AZURE_ITEM_PREFIX=<azure_item_prefix>
$ export AZURE_DOCKER_ADMIN_PASSWORD=<azure_docker_admin_password>
$ export SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)
```

## Contributing
To develop the template locally, use the DEBUG=true environment variable.  This points to the local azuredeploy.json file (azure/ee-windows/azuredeploy.json)

### Prerequisites
When running in `DEBUG` mode, the script will temporarily upload script files to a private gist, allowing you to test incremental changes before committing them to the repo

* [gist CLI](https://github.com/defunkt/gist)

### Deploying in Debug Mode - Bash
1. Set debug variable
```
$ export DEBUG=true
```
2. Login to Azure CLI (Optional if not already logged in)
```
$ az login
```
3. Login to GitHub Gist (Optional if not already logged in)
```
$ gist --login
```
4. Deploy using script
```
$ sh deploy.sh
```