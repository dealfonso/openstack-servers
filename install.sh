#!/bin/bash
cp openstack-servers.service /etc/systemd/system/
cp openstack-serversd.sh /usr/sbin/
cp openstack-servers.conf /etc/
chmod +x /usr/sbin/openstack-serversd.sh
mkdir -p /var/log/openstack-servers/
