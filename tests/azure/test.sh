#/bin/bash
echo "logging in"
az login  --service-principal -u $u -p $p --tenant $tenant -o table

#set variables
echo "setting variables"
export resource_group_name=broyal_ci$CIRCLE_BUILD_NUM
export location=eastus
export storage_account_name=broyalmta

#create resource group
echo "creating resource group"
az group create --name $resource_group_name --location $location

#get azuredeploy.parameters.json and add STORAGE_ACCOUNT_KEY
parameters="
{
    \"prefix\": {
        \"value\": \"broyal\"
    },
    \"adminUsername\": {
        \"value\": \"docker\"
    },
    \"adminPassword\": {
        \"value\": \"P@ssword1\"
    },
    \"sshPublicKey\": {
        \"value\": \"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdqs3DLhpiXMSOTgSk0X7pjOE8Jk502pX1qERGACbuArBFUGxBAjBl5c3wdenC/P8oYtvHFGN0syVCaqxsn87vp//IWTzF2LIOySJQ55N9Wq2SpNEiEOxtgrF5O4EhC8pwQphEwovChwVijOJEQl0WX2HhGZBTiDmTFrCVl22S0CCHymthkDtFsiE5LCXMbZvOk5olZEAzLymrO1SKjHsgQruZAFFWSxoyUPn2SmmD2Br6SQe9sQr4k+CCQ5q3NYXxsj0tpbnNIpKg85ozsQ9CUgc+06juEqahuj1p5DLkbZfHz0zlmPd3wbM02YLQNX8ZxdLBF4RLVSv4dW4NwPxf broyal@docker.com\"
    },
    \"vmSize\": {
        \"value\": \"Standard_DS2\"
    },
    \"storageDomain\": {
        \"value\": \"blob.core.windows.net\"
    },
    \"dnsFqdnSuffix\": {
        \"value\": \"cloudapp.azure.com\"
    },
    \"storageAccountName\": {
        \"value\": \"broyalci\"
    },
    \"storageAccountKey\": {
        \"value\": \""$STORAGE_ACCOUNT_KEY"\"
    },
    \"storageContainerName\": {
        \"value\": \"hotfix\"
    }
}
"
echo "starting deployment"
echo "exit code: $?"
az group deployment create --template-file ./azure/azuredeploy.json --parameters $parameters -g $resource_group_name

#force exit code from deployment failure
if [$? -ne 0]
then
    exit $?
fi