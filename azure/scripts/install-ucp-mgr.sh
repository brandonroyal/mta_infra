#!/bin/bash
if [ -z "$UCP_PUBLIC_FQDN" ]; then
    echo 'UCP_PUBLIC_FQDN is undefined'
    exit 1
fi

if [ -z "$UCP_ADMIN_PASSWORD" ]; then
    echo 'UCP_ADMIN_PASSWORD is undefined'
    exit 1
fi

if [ -z "$UCP_VERSION" ]; then
    echo 'UCP_VERSION is undefined'
    exit 1
fi

echo "---------------------------"
echo "Install Docker EE UCP Manager (install-ucp-mgr.sh)"
echo "---------------------------"
echo "UCP_VERSION=$UCP_VERSION"
echo "UCP_PUBLIC_FQDN=$UCP_PUBLIC_FQDN"
echo "UCP_ADMIN_PASSWORD=<secure_password>"

#start docker service
sudo service docker start

#install UCP
docker run --rm --name ucp \
  -v /var/run/docker.sock:/var/run/docker.sock \
   docker/ucp:$UCP_VERSION \
   install --san $UCP_PUBLIC_FQDN --admin-password $UCP_ADMIN_PASSWORD --debug

echo "---------------------------"
echo "Install Docker EE UCP Manager Complete"
echo "---------------------------"