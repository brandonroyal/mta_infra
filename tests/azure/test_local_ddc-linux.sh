#/bin/bash
set -e

#set variables
echo "setting variables"
export resource_group_name="broyal_test$RANDOM"
export location="eastus"
export storage_account_name="broyalmta$RANDOM"
export artifactBaseUri="https://$storage_account_name.blob.core.windows.net/artifacts/"

#create resource group
echo "creating resource group"
az group create --name $resource_group_name --location $location

#create storage account and container
az storage account create --name $storage_account_name --location $location --resource-group $resource_group_name --sku Standard_LRS
connectionString=$(az storage account show-connection-string --name $storage_account_name --resource-group $resource_group_name --key primary --query connectionString)
az storage container create --name artifacts --public-access blob --connection-string $connectionString

#upload script assets
for filepath in ./azure/scripts/*; do
    az storage blob upload -f $filepath -c artifacts -n $(basename $filepath) --connection-string $connectionString
done

if [ $1 == "RHEL" ]; then
    export vmImagePublisher=RedHat
    export vmImageOffer=RHEL
    export vmImageSKU=7.2
else
    export vmImagePublisher=canonical
    export vmImageOffer=ubuntuserver
    export vmImageSKU=16.04-LTS
fi

#add STORAGE_ACCOUNT_KEY to parameters
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
    \"artifactBaseUri\": {
        \"value\": \""$artifactBaseUri"\"
    },
    \"vmImagePublisher\": {
        \"value\": \""$vmImagePublisher"\" 
    },
    \"vmImageOffer\": {
        \"value\": \""$vmImageOffer"\" 
    },
    \"vmImageSKU\": {
        \"value\": \""$vmImageSKU"\" 
    }
}
"
echo $parameters

#perform test deployment
echo "starting deployment"
az group deployment create --template-file ./azure/ddc-linux/azuredeploy.json --parameters "$parameters" -g $resource_group_name --verbose

#test UCP and DTR web endpoints
echo 'testing UCP + DTR endpoints'
az network public-ip list -g $resource_group_name --query "[?contains(name,'_mgr_ucp')].{ipAddress: ipAddress}" -o table | tail -n +3 | xargs -I % curl -kI https://%
az network public-ip list -g $resource_group_name --query "[?contains(name,'_mgr_dtr')].{ipAddress: ipAddress}" -o table | tail -n +3 | xargs -I % curl -kI https://%