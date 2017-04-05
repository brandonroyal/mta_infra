#/bin/bash
set -e

#get tags
git fetch --tags

#variables
resource_group_name="broyal_ci"
storage_account_name="mtapoc"
tag=$(git describe --tags --abbrev=0)
tag=$(echo $tag | sed 's/[^a-zA-Z0-9]//g')

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