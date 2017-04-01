#/bin/bash
export resource_group_name=broyal_ci$CIRCLE_BUILD_NUM

#cleanup
echo "cleaning up deployment"
az group delete -n $resource_group_name -y