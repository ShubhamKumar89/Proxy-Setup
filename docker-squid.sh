#!/bin/bash
#
# Setup a Docker Squid Proxy Server

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

print_color "green" "\n\n---------------- Setup Squid Proxy Server ------------------\n\n"

# Install Squid
UBUNTU_VERSION=$(lsb_release -r | awk '{print $2}')

if [ "$UBUNTU_VERSION" == "20.04" ]; then
    docker run -d --name squid-container --restart=always -p 127.0.0.1:3128:3128 ubuntu/squid:4.10-20.04_beta
elif [ "$UBUNTU_VERSION" == "22.04" ]; then
    docker run -d --name squid-container --restart=always -p 127.0.0.1:3128:3128 ubuntu/squid:5.2-22.04_beta
else
    echo "Unsupported Ubuntu version: $UBUNTU_VERSION"
fi

# Check if the container is running
if docker container inspect squid-container >/dev/null 2>&1 && docker container inspect --format '{{.State.Running}}' squid-container | grep -q 'true'; then
  print_color "yellow" "The 'squid-container' is running"
else
  print_color "red" "The 'squid-container' is not running"
fi