#!/bin/bash
set -e

az account list

echo "------------------------"
echo "Deploying Docker EE"
echo "------------------------"
echo ""

if [[ -z "${AZURE_RESOURCE_GROUP_NAME// }" ]]; then
    echo "azure resource group name:"
    read AZURE_RESOURCE_GROUP_NAME
fi

if [[ -z "${AZURE_LOCATION// }" ]]; then
    echo "azure location:"
    read AZURE_LOCATION
fi

if [[ -z "${AZURE_ITEM_PREFIX// }" ]]; then
    echo "azure resource prefix:"
    read AZURE_ITEM_PREFIX
fi

if [[ -z "${AZURE_DOCKER_ADMIN_PASSWORD// }" ]]; then
    echo "admin password:"
    read -s AZURE_DOCKER_ADMIN_PASSWORD

    echo "confirm admin password:"
    read -s confirm_admin_password

    if [[ $AZURE_DOCKER_ADMIN_PASSWORD != $confirm_admin_password ]]; then
        echo "[error] passwords do not match!"
        exit 1
    fi
fi

if [[ -z "${SSH_PUBLIC_KEY// }" ]]; then
    default_ssh_public_key_path="$HOME/.ssh/id_rsa.pub"
    echo "ssh public key path ($default_ssh_public_key_path):"
    read ssh_public_key_path

    if [[ -z "${ssh_public_key_path}" ]]; then
        ssh_public_key_path=$default_ssh_public_key_path
    fi

    SSH_PUBLIC_KEY=$(cat "$ssh_public_key_path")
fi



echo "Resource Group Name: $AZURE_RESOURCE_GROUP_NAME"
echo "Azure Location: $AZURE_LOCATION"
echo "Resource Prefix: $AZURE_ITEM_PREFIX"
echo "Admin Password: <secure password>"
echo "SSH Public Key: $SSH_PUBLIC_KEY"
echo "Is this correct [y/n]?"
read continueAnswer
if [[ $continueAnswer != "y" ]]; then
    echo "cancelling script"
    exit
fi

az group create --name $AZURE_RESOURCE_GROUP_NAME --location $AZURE_LOCATION

if [[ $DEBUG == "true" ]]; then
    storage_account_name="$AZURE_ITEM_PREFIX$RANDOM"
    artifact_base_uri="https://$storage_account_name.blob.core.windows.net/artifacts/"

    #create storage account and container
    az storage account create --name $storage_account_name --location $AZURE_LOCATION --resource-group $AZURE_RESOURCE_GROUP_NAME --sku Standard_LRS
    connection_strong=$(az storage account show-connection-string --name $storage_account_name --resource-group $AZURE_RESOURCE_GROUP_NAME --key primary --query connectionString)
    az storage container create --name artifacts --public-access blob --connection-string $connection_strong

    #upload script assets
    for filepath in ./azure/scripts/*; do
        az storage blob upload -f $filepath -c artifacts -n $(basename $filepath) --connection-string $connection_strong
    done

    #set artifact base url parameter
    artifactBaseUriParameter="
    ,
    \"artifactBaseUri\": {
        \"value\": \""$artifactBaseUri"\"
    }
    "
fi

parameters="
{
    \"prefix\": {
        \"value\": \""$AZURE_ITEM_PREFIX"\"
    },
    \"adminUsername\": {
        \"value\": \"docker\"
    },
    \"adminPassword\": {
        \"value\": \""$AZURE_DOCKER_ADMIN_PASSWORD"\"
    },
    \"sshPublicKey\": {
        \"value\": \""$sshPublicKey"\"
    },
    \"dockerId\": {
        \"value\": \""$dockerId"\"
    },
    \"dockerPassword\": {
        \"value\": \""$dockerPassword"\"
    }
    $artifactBaseUriParameter
}
"


az group deployment create --template-file azuredeploy.json --parameters "$parameters" -g $AZURE_RESOURCE_GROUP_NAME --verbose