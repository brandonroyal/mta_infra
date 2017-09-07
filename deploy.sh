#!/bin/bash
set -e

az account list

echo "------------------------"
echo "Deploying Docker EE"
echo "------------------------"
echo ""

DOCKER_ENGINE_VERSION="17.06.1-ee-2"
DOCKER_UCP_VERSION="2.2.2"
DOCKER_DTR_VERSION="2.3.2"
#TODO: Check versions return a 200

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

echo "[INFO] creating resource group"
az group create --name $AZURE_RESOURCE_GROUP_NAME --location $AZURE_LOCATION

if [[ $DEBUG == "true" ]]; then
    storage_account_name="$AZURE_ITEM_PREFIX$RANDOM"
    artifact_base_uri="https://$storage_account_name.blob.core.windows.net/artifacts/"

    #create storage account and container
    echo "[DEBUG] creating storage account: $storage_account_name"
    az storage account create --name $storage_account_name --location $AZURE_LOCATION --resource-group $AZURE_RESOURCE_GROUP_NAME --sku Standard_LRS

    echo "[DEBUG] establishing connection string"
    connection_string=$(az storage account show-connection-string --name $storage_account_name --resource-group $AZURE_RESOURCE_GROUP_NAME -o json --key primary --query connectionString)


    echo "[DEBUG] creating storage container: artifacts"
    az storage container create --name artifacts --public-access blob --connection-string $connection_string

    #upload script assets
    for filepath in ./azure/scripts/*; do
        echo "[DEBUG] uploading artifact: $filepath"
        az storage blob upload -f $filepath -c artifacts -n $filepath --connection-string $connection_string
    done

    #set artifact base url parameter
    artifactBaseUriParameter="
    ,
    \"artifactBaseUri\": {
        \"value\": \""$artifact_base_uri"\"
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
        \"value\": \""$SSH_PUBLIC_KEY"\"
    },
    \"dockerVersion\": {
        \"value\": \""$DOCKER_ENGINE_VERSION"\"
    },
    \"ucpVersion\": {
        \"value\": \""$DOCKER_UCP_VERSION"\"
    },
    \"dtrVersion\": {
        \"value\": \""$DOCKER_DTR_VERSION"\"
    }
    $artifactBaseUriParameter
}
"

if [[ $DEBUG == "true" ]]; then
    echo "[DEBUG] using parameters:"
    echo $parameters
    echo "[DEBUG] creating deployment"
    az group deployment create \
        --template-file azure/ee-windows/azuredeploy.json \
        --parameters "$parameters" \
        -g $AZURE_RESOURCE_GROUP_NAME \
        --verbose
else
    echo "[INFO] creating deployment"
    az group deployment create \
        --template-uri https://raw.githubusercontent.com/BrandonRoyal/mta_infra/master/azure/ee-windows/azuredeploy.json \
        --parameters "$parameters" \
        -g $AZURE_RESOURCE_GROUP_NAME \
        --verbose
fi
