#/bin/bash
set -e

#variables
export resource_group_name="broyalmta"
export storage_account_name="mtapoc"

connectionString=$(az storage account show-connection-string --name $storage_account_name --resource-group $resource_group_name --key primary --query connectionString)
az storage container create --name artifacts --public-access blob --connection-string $connectionString