#!/bin/bash
set -e

az account list

echo "------------------------"
echo "Deploying Docker EE"
echo "------------------------"
echo ""

DOCKER_ENGINE_VERSION="17.06.2-ee-3"
DOCKER_UCP_VERSION="2.2.3"
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

    #upload script assets
    paths=""
    for filepath in ./azure/scripts/*; do
        echo "[DEBUG] adding script to upload queue: $filepath"
        paths="$paths $filepath"
    done

    echo "[DEBUG] uploading scripts"
    #upload files using gist CLI
    scripts_base_uri=$(gist -pR $paths)
    #add trailing / to url (needed for concat joins later)
    scripts_base_uri="$scripts_base_uri/"

    #set artifact base url parameter
    artifactBaseUriParameter="
    ,
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

if [[ $DEBUG == "true" ]]; then
    echo "[DEBUG] setting trap to cleanup gist on exit"
    # trap "gist --delete $scripts_base_uri" EXIT
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

# get ucp hostname
echo "[INFO] getting ucp hostname"
ucp_hostname=$(az network public-ip list -g $AZURE_RESOURCE_GROUP_NAME --query "[].{DNS:dnsSettings.fqdn}" | grep ucp)

# check availability of UCP
echo "[INFO] getting ucp status"
ucp_status=$(curl -sL -w "%{http_code}\\n" "https://$ucp_hostname/" -o /dev/null)
echo "[INFO] ucp status: $ucp_status"
#TODO: add if statement and retry loop

# download client bundle
echo "[INFO] download ucp client bundle"
ucp_authtoken=$(curl -sk -d '{"username":"admin","password":"'$AZURE_DOCKER_ADMIN_PASSWORD'"}' https://$ucp_hostname/auth/login | jq -r .auth_token)
curl -sk -H "Authorization: Bearer $ucp_authtoken" https://$ucp_hostname/api/clientbundle -o /tmp/$ucp_hostname-bundle.zip
echo "[INFO] extracting ucp client bundle"
mkdir -p /tmp/$ucp_hostname
unzip /tmp/$ucp_hostname-bundle.zip -d /tmp/$ucp_hostname

# connect to UCP via client bundle
echo "[INFO] connecting to ucp cluster"
origin_pwd=$(pwd)
cd /tmp/$ucp_hostname
. env.sh
cd $origin_pwd

# deploy CI stack
JENKINS_USERNAME=admin
JENKINS_PASSWORD=P@ssword1

# wget https://raw.githubusercontent.com/BrandonRoyal/mta_ci/d510f3b35f7930fc74f35d57c34f82f62aa41a5e/docker-compose.yml -O ./ci_stack.yml
# wget https://raw.githubusercontent.com/BrandonRoyal/mta_ci/master/configs/automation/config.xml -O ./config.xml
# wget https://raw.githubusercontent.com/BrandonRoyal/mta_ci/master/configs/git/app.ini -O ./app.ini

echo "[INFO] adding jenkins_mta_job config.xml config"
docker config create jenkins_mta_job config.xml
echo "[INFO] adding gogs_app_ini app.ini config"
docker config create gogs_app_ini app.ini

echo "[INFO] adding jenkins-user secret"
echo "$JENKINS_USERNAME" | docker secret create jenkins-user -
echo "[INFO] adding jenkins-pass secret"
echo "$JENKINS_PASSWORD" | docker secret create jenkins-pass -

echo "[INFO] deploying CI stack"
docker stack deploy -c ./ci_stack.yml ci