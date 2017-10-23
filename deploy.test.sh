

AZURE_DOCKER_ADMIN_PASSWORD=P@ssword1
AZURE_RESOURCE_GROUP_NAME=broyal_dceu2

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