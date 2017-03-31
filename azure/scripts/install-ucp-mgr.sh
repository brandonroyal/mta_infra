#!/bin/bash
if [ -z "$UCP_PUBLIC_FQDN" ]; then
    echo 'UCP_PUBLIC_FQDN is undefined'
    exit 1
fi

if [ -z "$UCP_ADMIN_PASSWORD" ]; then
    echo 'UCP_ADMIN_PASSWORD is undefined'
    exit 1
fi

if [ -z "$UCP_HOST_ADDRESS" ]; then
    export eth1=$(ifconfig -s | grep 'eth1');
    if [ -z "$eth1" ];
        then
            eval UCP_HOST_ADDRESS=$(ifconfig eth0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)
        else
            eval UCP_HOST_ADDRESS=$(ifconfig eth1 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)      
    fi
fi

echo "UCP_PUBLIC_FQDN=$UCP_PUBLIC_FQDN"
echo "UCP_HOST_ADDRESS=$UCP_HOST_ADDRESS"

#install UCP
docker run --rm --name ucp \
  -v /var/run/docker.sock:/var/run/docker.sock \
   docker/ucp:2.1.1 \
   install --enable-windows --host-address $UCP_HOST_ADDRESS --san $UCP_PUBLIC_FQDN --admin-password $UCP_ADMIN_PASSWORD --debug