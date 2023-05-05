!/bin/bash
#
# Configure docker to use squid proxy server along with docker installation

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

# Update the apt package index and install packages to allow apt to use a repository over HTTPS
apt-get update
apt-get install \
    ca-certificates \
    curl \
    gnupg

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the apt package index
apt-get update

# Install Docker Engine, containerd, and Docker Compose
print_color "green" "\n\nInstalling Docker Engine, containerd, and Docker Compose.. "
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Check docker Service is running
check_service_status "docker"

print_color "green" "\n\n---------------- Configure Docker to use the Squid proxy ----------------\n\n"

# Configure Docker to use the Squid proxy
mkdir -p ~/.docker
cat > ~/.docker/config.json << EOF
{
  "proxies": {
    "default": {
      "httpProxy": "http://localhost:3128",
      "httpsProxy": "http://localhost:3128",
      "noProxy": "localhost,127.0.0.1,::1"
    }
  }
}
EOF

export DOCKER_CONFIG=~/.docker

# Configure the Docker service to use the Squid proxy
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=http://localhost:3128"
Environment="HTTPS_PROXY=http://localhost:3128"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF

# Reload the systemd configuration and restart the Docker service
systemctl daemon-reload
systemctl restart docker.service