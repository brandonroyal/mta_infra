#!/bin/bash
sed "s/{{host_ip}}/${HOST_IP}/g" interfaces > interfaces-complete
mv interfaces-complete /etc/network/interfaces
ip addr flush dev eth1
service networking restart