#/bin/bash
az login  --service-principal -u $u -p $p --tenant $tenant

export resource_group_name=broyal_ci$CIRCLE_BUILD_NUM
export location=eastus
export storage_account_name=broyalmta

az group create --name $resource_group_name --location $location

#sed "s/{{storageAccountKey}}/${STORAGE_ACCOUNT_KEY}/g" azuredeploy.parameters.json > azuredeploy.parameters2.json
cat azuredeploy.parameters.json

#cleanup
az group delete -n $resource_group_name -y