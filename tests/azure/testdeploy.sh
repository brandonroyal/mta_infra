#/bin/bash
az login  --service-principal -u $u -p $p --tenant $tenant

export resource_group_name=broyal_ci$CIRCLE_BUILD_NUM
export location=eastus
export storage_account_name=broyalmta

az group create --name $resource_group_name --location $location

search="{{storageAccountKey}}"

echo $PWD
sed -i "" "s/${search}/${storageAccountKey}/g" ./azuredeploy.parameters.json
cat ./tests/azure/azuredeploy.parameters.json

#cleanup
az group delete -n $resource_group_name -y