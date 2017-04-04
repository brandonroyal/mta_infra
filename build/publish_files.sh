#/bin/bash
set -e

#get tags
git fetch --tags

#variables
export resource_group_name="broyalmta"
export storage_account_name="mtapoc"
export tag=$(git describe --tags --abbrev=0)

connectionString=$(az storage account show-connection-string --name $storage_account_name --resource-group $resource_group_name --key primary --query connectionString)
az storage container create --name tag --public-access blob --connection-string $connectionString