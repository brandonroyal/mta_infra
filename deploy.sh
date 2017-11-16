#!/bin/bash
# set -e

echo "------------------------"
echo "Deploying Docker EE"
echo "------------------------"
echo ""

DOCKER_ENGINE_VERSION="17.06.2-ee-4"
DOCKER_UCP_VERSION="2.2.2"
DOCKER_DTR_VERSION="2.3.4"
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

if [[ $DEBUG == "true" ]]; then

    #upload script assets
    echo "#MTA Infra - Scripts" >> ./azure/scripts/README.md
    IFS='/' read -r -a scripts_uri_array <<< "$(gist -pR ./azure/scripts/README.md)"
    scripts_base_uri="https://gist.github.com/${scripts_uri_array[3]}/${scripts_uri_array[4]}/raw/"
    scripts_gist_id=${scripts_uri_array[4]}
    rm ./azure/scripts/README.md
    for filepath in ./azure/scripts/*; do
        echo "[DEBUG] uploading $filepath"
        url=$(gist -u $scripts_gist_id $filepath)
    done
    echo "[DEBUG] scripts base url: $scripts_base_uri"

    #upload template assets
    echo "#MTA Infra - Templates" >> ./azure/ee-windows/README.md
    IFS='/' read -r -a templates_uri_array <<< "$(gist -pR ./azure/ee-windows/README.md)"
    templates_base_uri="https://gist.github.com/${templates_uri_array[3]}/${templates_uri_array[4]}/raw/"
    templates_gist_id=${templates_uri_array[4]}
    rm ./azure/ee-windows/README.md
    for filepath in ./azure/ee-windows/*; do
        echo "[DEBUG] uploading $filepath"
        url=$(gist -u $templates_gist_id $filepath)
    done
    echo "[DEBUG] templates base url: $templates_base_uri"  

    #set artifact base url parameter
    artifactBaseUriParameter="
    ,
    \"templatesBaseUri\": {
        \"value\": \""$templates_base_uri"\"
    },
    \"scriptsBaseUri\": {
        \"value\": \""$scripts_base_uri"\"
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
#create resource group
echo "[INFO] creating resource group: $AZURE_RESOURCE_GROUP_NAME"
rg=$(az group create --name $AZURE_RESOURCE_GROUP_NAME --location $AZURE_LOCATION)

if [[ $DEBUG == "true" ]]; then
    echo "[DEBUG] setting trap to cleanup gist on exit"
    trap "echo '[DEBUG] cleaning up gist scripts and templates'; gist --delete $scripts_gist_id; gist --delete $templates_gist_id" EXIT
    echo "[DEBUG] creating deployment"
    az group deployment create \
        --template-file azure/ee-windows/index.json \
        --parameters "$parameters" \
        -g $AZURE_RESOURCE_GROUP_NAME \
        --verbose
else
    echo "[INFO] creating deployment"
    az group deployment create \
        --template-uri https://raw.githubusercontent.com/BrandonRoyal/mta_infra/master/azure/ee-windows/index.json \
        --parameters "$parameters" \
        -g $AZURE_RESOURCE_GROUP_NAME \
        --verbose
fi

az network public-ip list --query "[].{name:name, fqdn:dnsSettings.fqdn}" -g $AZURE_RESOURCE_GROUP_NAME