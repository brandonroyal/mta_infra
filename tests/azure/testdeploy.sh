#/bin/bash
az login  --service-principal -u $u -p $p --tenant $tenant

#set variables
export resource_group_name=broyal_ci$CIRCLE_BUILD_NUM
export location=eastus
export storage_account_name=broyalmta

#create resource group
az group create --name $resource_group_name --location $location

#get azuredeploy.parameters.json and add STORAGE_ACCOUNT_KEY
params_template=$(cat ./tests/azure/azuredeploy.template.json)
parameters="${params_template/STORAGE_ACCOUNT_KEY/$STORAGE_ACCOUNT_KEY}"

az group deployment create --template-file ./azure/azuredeploy.json --parameters $parameters -g 

#cleanup
az group delete -n $resource_group_name -y