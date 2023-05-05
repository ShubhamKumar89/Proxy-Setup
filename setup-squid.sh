#!/bin/bash
#
# Setup Squid Proxy Server

set -e

#######################################
# Print a message in a given color.
# Arguments:
#   Color. eg: green, red
#######################################
function print_color(){
  NC='\033[0m' # No Color
  case $1 in
    "green") COLOR='\033[0;32m' ;;
    "red") COLOR='\033[0;31m' ;;
    "yellow") COLOR='\033[0;33m' ;;
    "blue") COLOR='\033[0;34m' ;;
    "*") COLOR='\033[0m' ;;
  esac

  echo -e "${COLOR} $2 ${NC}"
}

#######################################
# Check the status of a given service. If not active exit script
# Arguments:
#   Service Name. eg: firewalld, mariadb
#######################################
function check_service_status(){
  service_is_active=$(systemctl is-active $1)

  if [ $service_is_active = "active" ]
  then
    print_color "yellow" "$1 is active and running"
  else
    print_color "red" "$1 is not active/running"
    exit 1
  fi
}

# Check if the script is running as root
if [[ $EUID -ne 0 ]]; then
    print_color "red" "This script must be run as a super user (root). Exiting."
    exit 1
fi

# Update packages and install Squid
apt update
apt install -y squid

# Backup the original Squid configuration file
cp /etc/squid/squid.conf /etc/squid/backup.conf

# Modify the Squid configuration file
cat > /etc/squid/squid.conf << EOF
acl localnet src 0.0.0.1-0.255.255.255
acl localnet src 10.0.0.0/8
acl localnet src 100.64.0.0/10
acl localnet src 169.254.0.0/16
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
include /etc/squid/conf.d/*

# change ip address to your squid server ip address
acl localnet src 192.168.5.198

http_access allow localnet

http_access allow localhost

http_access allow all

http_port 0.0.0.0:3128
http_port [::]:3128

coredump_dir /var/spool/squid
refresh_pattern ^ftp:        1440    20%    10080
refresh_pattern ^gopher:     1440    0%     1440
refresh_pattern -i (/cgi-bin/|\?) 0    0%     0
refresh_pattern \/(Packages|Sources)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern \/Release(|\.gpg)$ 0 0% 0 refresh-ims
refresh_pattern \/InRelease$ 0 0% 0 refresh-ims
refresh_pattern \/(Translation-.*)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern .            0    20%    4320
EOF

# Start Squid service 
systemctl restart squid

# Check Squid Service is running
check_service_status "squid"