#!/bin/bash
if [ -z "$UCP_PUBLIC_FQDN" ]; then
    echo 'UCP_PUBLIC_FQDN is undefined'
    exit 1
fi

if [ -z "$UCP_ADMIN_PASSWORD" ]; then
    echo 'UCP_ADMIN_PASSWORD is undefined'
    exit 1
fi

if [ -z "$DTR_PUBLIC_FQDN" ]; then
    echo 'DTR_PUBLIC_FQDN is undefined'
    exit 1
fi

if [ -z "$DTR_VERSION" ]; then
    echo 'DTR_VERSION is undefined'
    exit 1
fi

if [ -z "$UCP_NODE"]; then
  export UCP_NODE=$(docker node ls | grep mgr0 | awk '{print $3}');
fi

echo "---------------------------"
echo "Install Docker Trusted Registry (install-dtr-mgr.sh)"
echo "---------------------------"
echo "UCP_PUBLIC_FQDN=$UCP_PUBLIC_FQDN"
echo "UCP_ADMIN_PASSWORD=<secure_password>"
echo "DTR_PUBLIC_FQDN=$DTR_PUBLIC_FQDN"
echo "DTR_VERSION=$DTR_VERSION"
echo "UCP_NODE=$UCP_NODE"

#start docker service
sudo service docker start

#install DTR
docker run --rm \
  docker/dtr:$DTR_VERSION install \
  --ucp-url $UCP_PUBLIC_FQDN \
  --ucp-node $UCP_NODE \
  --dtr-external-url $DTR_PUBLIC_FQDN \
  --ucp-username admin --ucp-password $UCP_ADMIN_PASSWORD \
  --ucp-insecure-tls \
  --replica-http-port 8081 \
  --replica-https-port 8443

echo "---------------------------"
echo "Install Docker Trusted Registry (install-dtr-mgr.sh)"
echo "---------------------------"