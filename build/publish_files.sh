#/bin/bash
set -e

#get tags
git fetch --tags

#variables
resource_group_name="broyal_ci"
storage_account_name="mtapoc"
tag=$(git describe --tags --abbrev=0)
export tag=$(echo $tag | sed 's/[^a-zA-Z0-9]//g')

#get storage account connection string
connectionString=$(az storage account show-connection-string --name $storage_account_name --resource-group $resource_group_name --key primary --query connectionString)

#create container if not exists
if [ -z "$(az storage container show --name $tag --connection-string $connectionString)" ]
then
    az storage container create --name $tag --public-access blob --connection-string $connectionString
fi

#upload assets
upload_assets () {
    filepath=$1
    echo $filepath
    az storage blob upload -f $filepath -c $tag -n $(basename $filepath) --connection-string $connectionString
}

for filepath in ./azure/scripts/*; do
    upload_assets $filepath
done

for filepath in ./azure/_shared/*; do
    upload_assets $filepath
done

for filepath in ./azure/ddc/*; do
    upload_assets $filepath
done

for filepath in ./docs/*; do
    upload_assets $filepath
done

#create new routes for documentation
export APP_ROUTES="
[
    { 
        \"redirect\": true, \"path\": \"/v2\", \"redirectPath\": \"/\"
    },
    {
        \"title\": \"Modernizing Traditional Applications POC // Azure Deployment\",
        \"path\": \"/\",
        \"nextTitle\": \"Deploy Test App\",
        \"nextPath\": \"/test-app\",
        \"sourceHost\": \"mtapoc.blob.core.windows.net\",
        \"sourcePath\": \"/$tag/mta_poc_azure_deployment.md\"
    },
    {
        \"title\": \"Modernizing Traditional Applications POC // Deploy Test App\",
        \"path\": \"/test-app\",
        \"previousTitle\": \"Azure Infrastructure Deployment\",
        \"previousPath\": \"/\",
        \"sourceHost\": \"mtapoc.blob.core.windows.net\",
        \"sourcePath\": \"/$tag/mta_poc_test_app.md\"
    }
]
"

# copy routes and update service
echo $APP_ROUTES > routes.json
scp routes.json docker@mta.dckr.org:/home/docker/routes.json
ssh -T docker@mta.dckr.org 'bash -s' << 'ENDSSH'
    docker service update --mount-add type=bind,source=`pwd`/routes.json,destination=/app/routes.json --image broyal/www-markdown:1.3 www
ENDSSH