#!/usr/bin/env bash

set -e

header() {
  clear
  echo -e "📦 \033[1;32mNewsDash Installer for Proxmox\033[0m"
  echo "----------------------------------------"
}

prompt() {
  read -p "🆔 ID du conteneur [112]: " CT_ID
  CT_ID=${CT_ID:-112}
  read -p "📛 Nom d'hôte [newsdash]: " CT_NAME
  CT_NAME=${CT_NAME:-newsdash}
  read -p "💾 Taille disque (ex: 4G) [4G]: " DISK_SIZE
  DISK_SIZE=${DISK_SIZE:-4G}
  read -p "🧠 RAM (en Mo) [512]: " MEMORY
  MEMORY=${MEMORY:-512}
  read -p "🧮 CPU cores [1]: " CORES
  CORES=${CORES:-1}
  read -p "🔑 Mot de passe root [changeme]: " PASSWORD
  PASSWORD=${PASSWORD:-changeme}
  echo "🌐 IP :"
  echo "1) DHCP"
  echo "2) IP statique"
  read -p "Choix [1/2]: " IP_MODE
  if [[ "$IP_MODE" == "2" ]]; then
    read -p "🧭 IP (ex: 192.168.1.112/24): " STATIC_IP
    read -p "🌐 Passerelle (ex: 192.168.1.1): " GATEWAY
    IP="ip=$STATIC_IP,gw=$GATEWAY"
  else
    IP="ip=dhcp"
  fi
}

create_lxc() {
  echo "📦 Création du conteneur LXC..."
  pct create $CT_ID local:vztmpl/debian-12-standard_*.tar.zst \
    -hostname $CT_NAME \
    -storage local-lvm \
    -rootfs $DISK_SIZE \
    -memory $MEMORY \
    -cores $CORES \
    -net0 name=eth0,bridge=vmbr0,$IP \
    -password $PASSWORD \
    -features nesting=1 \
    -unprivileged 1
  pct start $CT_ID
  sleep 5
}

install_docker() {
  echo "🐳 Installation de Docker et Docker Compose..."
  pct exec $CT_ID -- bash -c "apt update && apt install -y curl sudo gnupg2 ca-certificates lsb-release software-properties-common"
  pct exec $CT_ID -- bash -c "curl -fsSL https://get.docker.com | sh"
  pct exec $CT_ID -- bash -c "usermod -aG docker root"
  pct exec $CT_ID -- bash -c "curl -L https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose"
  pct exec $CT_ID -- bash -c "chmod +x /usr/local/bin/docker-compose"
}

deploy_newsdash() {
  echo "🚀 Déploiement de NewsDash..."
  pct exec $CT_ID -- bash -c "mkdir -p /opt/newsdash && cd /opt/newsdash && echo '
version: \"3.8\"
services:
  newsdash:
    image: joshuavial/newsdash
    container_name: newsdash
    ports:
      - \"8080:3000\"
    volumes:
      - ./config:/app/config
    restart: unless-stopped
' > docker-compose.yml"
  pct exec $CT_ID -- bash -c "cd /opt/newsdash && docker-compose up -d"
}

show_result() {
  echo "✅ Installation terminée !"
  IP_ADDR=$(pct exec $CT_ID -- hostname -I | awk '{print $1}')
  echo "➡️ Accédez à NewsDash via : http://$IP_ADDR:8080"
}

### Main
header
prompt
create_lxc
install_docker
deploy_newsdash
show_result
