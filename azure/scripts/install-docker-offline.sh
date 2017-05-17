#!/bin/bash
yum install -y docker-engine-selinux-17.05.0.ce-1.el7.centos.noarch.rpm
yum install -y docker-engine-17.05.0.ce-1.el7.centos.x86_64.rpm
sudo service docker start