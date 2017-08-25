#!/bin/bash
set -e

echo "Deploying Docker EE"
echo "------------------------"
echo ""

if [[ -z "${resource_group_name// }" ]]; then
    echo "Resource Group Name:"
    read resource_group_name
fi

if [[ -z "${location// }" ]]; then
    echo "Azure Location:"
    read location
fi

if [[ -z "${prefix// }" ]]; then
    echo "Resource Prefix:"
    read prefix
fi

if [[ -z "${adminPassword// }" ]]; then
    echo "Admin Password:"
    read adminPassword
fi

if [[ -z "${sshPublicKey// }" ]]; then
    echo "SSH Public Key:"
    read sshPublicKey
fi

if [[ -z "${dockerId// }" ]]; then
    echo "Docker ID:"
    read dockerId
fi

if [[ -z "${dockerPassword// }" ]]; then
    echo "Docker Password:"
    read -s dockerPassword
fi

echo "Resource Group Name: $resource_group_name"
echo "Azure Location: $location"
echo "Resource Prefix: $prefix"
echo "Admin Password: $adminPassword"
echo "SSH Public Key: $sshPublicKey"
echo "Docker ID: $dockerId"
echo "Docker Password: <secure password>"
echo "Is this correct [y/n]?"
read continueAnswer
if [[ $continueAnswer != "y" ]]; then
    echo "cancelling script"
    exit
fi

az group create --name $resource_group_name --location $location

if [[ $DEBUG == "true" ]]; then
    storage_account_name="$prefix$RANDOM"
    artifactBaseUri="https://$storage_account_name.blob.core.windows.net/artifacts/"

    #create storage account and container
    az storage account create --name $storage_account_name --location $location --resource-group $resource_group_name --sku Standard_LRS
    connectionString=$(az storage account show-connection-string --name $storage_account_name --resource-group $resource_group_name --key primary --query connectionString)
    az storage container create --name artifacts --public-access blob --connection-string $connectionString

    #upload script assets
    for filepath in ./azure/scripts/*; do
        az storage blob upload -f $filepath -c artifacts -n $(basename $filepath) --connection-string $connectionString
    done

    #set artifact base url parameter
    artifactBaseUriParameter="
    ,
    \"artifactBaseUri\": {
        \"value\": \""$artifactBaseUri"\"
    }
    "
fi

# parameters="
# {
#     \"prefix\": {
#         \"value\": \""$prefix"\"
#     },
#     \"adminUsername\": {
#         \"value\": \"docker\"
#     },
#     \"adminPassword\": {
#         \"value\": \""$adminPassword"\"
#     },
#     \"sshPublicKey\": {
#         \"value\": \""$sshPublicKey"\"
#     },
#     \"dockerId\": {
#         \"value\": \""$dockerId"\"
#     },
#     \"dockerPassword\": {
#         \"value\": \""$dockerPassword"\"
#     }
#     $artifactBaseUriParameter
# }
# "


# az group deployment create --template-file azuredeploy.json --parameters "$parameters" -g $resource_group_name --verbose