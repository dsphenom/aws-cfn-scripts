#!/bin/bash

## On-Premise Public IP, ie use http://whatsmyip.org to check
PUBIP=<INSERT PUBLIC IP>

## Outside Customer Gateway Public IP 1
OCGW1=<INSERT PUBLIC IP>
## Outside VPC Virtual Gateway Public IP 1
OVGW1=<INSERT VPN ENDPOINT 1>
## Pre-Shared Key 1
KEY1=<INSERT VPN TUNNEL KEY 1>
## Inside Customer Gateway Private CIDR (169.X.X.X/X)
ICGW1=<INSERT VPN INSIDE ADDR CGW 1>
## Inside VPC Virtual Gateway Private CIDR (169.X.X.X/X)
IVGW1=<INSERT VPN INSIDE ADDR VGW 1>

## Outside Customer Gateway Public IP 2
OCGW2=<INSERT PUBLIC IP>
## Outside VPC Virtual Gateway Public IP 2
OVGW2=<INSERT VPN ENDPOINT 2>
## Pre-Shared Key 2
KEY2=<INSERT VPN TUNNEL KEY 2>
## Inside Customer Gateway Private CIDR (169.X.X.X/X)
ICGW2=<INSERT VPN INSIDE ADDR CGW 2>
## Inside VPC Virtual Gateway Private CIDR (169.X.X.X/X)
IVGW2=<INSERT VPN INSIDE ADDR VGW 2>

## Customer Gateway ASN
CASN=<INSERT CGW ASN>
## Virtual Private  Gateway ASN
VASN=<INSERT VGW ASN>

## On-Premise Local Network
LNET=<INSERT LOCAL NETWORK CIDR ADDR>
## VPC Network
VNET=<INSERT VPC NETWORK CIDR ADDR>

function usage()
{
	echo "Don't forget to add parameters"
}

[ -z "$OCGW1" ] && usage
[ -z "$OVGW1" ] && usage
[ -z "$ICGW1" ] && usage
[ -z "$IVGW1" ] && usage
[ -z "$KEY1" ] && usage

[ -z "$OCGW2" ] && usage
[ -z "$OVGW2" ] && usage
[ -z "$ICGW2" ] && usage
[ -z "$IVGW2" ] && usage
[ -z "$KEY2" ] && usage

[ -z "$VNET" ] && usage
[ -z "$PUBIP" ] && usage
[ -z "$CASN" ] && usage
[ -z "$VASN" ] && usage

echo ##########
echo "Install required packages..."
PACKAGES="ipsec-tools racoon quagga ipcalc"
apt-get install $PACKAGES

echo ##########
echo "Setting up Pre-Shared Keys (/etc/racoon/psk.txt)"
cat <<EOF > /etc/racoon/psk.txt
$OVGW1	$KEY1
$OVGW2	$KEY2
EOF

echo ##########
echo "Setting up IPSec policies (/etc/ipsec-tools.conf)"
cat <<EOF > /etc/ipsec-tools.conf
flush;
spdflush;

spdadd $ICGW1 $IVGW1 any -P out ipsec
   esp/tunnel/${OCGW1}-${OVGW1}/require;

spdadd $IVGW1 $ICGW1 any -P in ipsec
   esp/tunnel/${OVGW1}-${OCGW1}/require;

spdadd $ICGW2 $IVGW2 any -P out ipsec
   esp/tunnel/${OCGW2}-${OVGW2}/require;

spdadd $IVGW2 $ICGW2 any -P in ipsec
   esp/tunnel/${OVGW2}-${OCGW2}/require;

spdadd $ICGW1 $VNET any -P out ipsec
   esp/tunnel/${OCGW1}-${OVGW1}/require;

spdadd $VNET $ICGW1 any -P in ipsec
   esp/tunnel/${OVGW1}-${OCGW1}/require;

spdadd $ICGW2 $VNET any -P out ipsec
   esp/tunnel/${OCGW2}-${OVGW2}/require;

spdadd $VNET $ICGW2 any -P in ipsec
   esp/tunnel/${OVGW2}-${OCGW2}/require;

spdadd $LNET $VNET any -P out ipsec
   esp/tunnel/${OCGW1}-${OVGW1}/require;

spdadd $VNET $LNET any -P in ipsec
   esp/tunnel/${OVGW1}-${OCGW1}/require;

spdadd $LNET $VNET any -P out ipsec
   esp/tunnel/${OCGW2}-${OVGW2}/require;

spdadd $VNET $LNET any -P in ipsec
   esp/tunnel/${OVGW2}-${OCGW2}/require;

EOF

echo ##########
echo "Setting up cryptographic parameters for IPSEC tunnels (/etc/racoon/racoon.conf)"
cat <<EOF > /etc/racoon/racoon.conf
log notify;
path pre_shared_key "/etc/racoon/psk.txt";
path certificate "/etc/racoon/certs";

remote $OVGW1 {
        exchange_mode main;
        lifetime time 28800 seconds;
        proposal {
                encryption_algorithm aes128;
                hash_algorithm sha1;
                authentication_method pre_shared_key;
                dh_group 2;
        }
        generate_policy off;
        #nat_traversal on;
}

remote $OVGW2 {
        exchange_mode main;
        lifetime time 28800 seconds;
        proposal {
                encryption_algorithm aes128;
                hash_algorithm sha1;
                authentication_method pre_shared_key;
                dh_group 2;
        }
        generate_policy off;
        #nat_traversal on;
}

sainfo address $ICGW1 any address $IVGW1 any {
        pfs_group 2;
        lifetime time 3600 seconds;
        encryption_algorithm aes128;
        authentication_algorithm hmac_sha1;
        compression_algorithm deflate;
}

sainfo address $ICGW2 any address $IVGW2 any {
        pfs_group 2;
        lifetime time 3600 seconds;
        encryption_algorithm aes128;
        authentication_algorithm hmac_sha1;
        compression_algorithm deflate;
}
EOF

echo ##########
echo "Setting up inside IP address..."
ip a a $ICGW1 dev eth0
ip a a $ICGW2 dev eth0

echo ##########
echo "Starting IPSEC tunnel service..."
/etc/init.d/racoon start
/etc/init.d/setkey start

echo ##########
echo "Setting up BGP Routing... (/etc/quagga/daemons)"
sed -i -e 's/^zebra.*/zebra=yes/g' /etc/quagga/daemons
sed -i -e 's/^bgpd.*/bgpd=yes/g' /etc/quagga/daemons

echo ##########
echo "Setting up BGP config... (/etc/quagga/bgpd.conf)"
IVGW1=$(ipcalc -bn $IVGW1 | awk '$1 == "Address:" {print $2}')
IVGW2=$(ipcalc -bn $IVGW2 | awk '$1 == "Address:" {print $2}')
cat <<EOF > /etc/quagga/bgpd.conf
hostname ec2-vpn
password testPassword
enable password testPassword
!
log file /var/log/quagga/bgpd
!debug bgp events
!debug bgp zebra
debug bgp updates
!
router bgp $CASN
bgp router-id $PUBIP
network $ICGW1
network $ICGW2
network $LNET
! aws tunnel #1 neighbor
neighbor $IVGW1 remote-as $VASN
!
! aws tunnel #2 neighbor
neighbor $IVGW2 remote-as $VASN
!
line vty
EOF

echo "Setting up Zebra config... (/etc/quagga/zebra.conf)"
cat <<EOF > /etc/quagga/zebra.conf
hostname ec2-vpn
password testPassword
enable password testPassword
!
! list interfaces
interface eth0
interface lo
!
line vty
EOF

echo "Starting Quagga routing service..."
/etc/init.d/quagga start
