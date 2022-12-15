#!/bin/bash

# Setup networking so that the falcon VMs can communicate over IPv4 NAT
# with the outside world and speak IPv6 to the host on a specific network.

set -o xtrace

#
# Enable packet filtering
#
ipf -E

#
# Create an etherstub to and host vnic for our private network
#
dladm create-etherstub om_stub0
dladm create-vnic -l om_stub0 om_host0

#
# Create our host addresses
#
ipadm create-addr -T addrconf om_host0/linklocal
ipadm create-addr -T static -a fc00::100:f/64 om_host0/v6
ipadm create-addr -T static -a 192.168.3.100/24 om_host0/v4

# Enable ipv4-forwarding on host so that we can setup NAT
routeadm -e ipv4-forwarding -u

# Enable ipfilter for NAT purposes
svcadm enable ipfilter

# Enable NAT for outbound traffic from our private network
ipnat -f ipnat.conf

