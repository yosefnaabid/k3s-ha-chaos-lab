#!/usr/bin/env bash
# Instala k3s en alta disponibilidad (3 servers con etcd) por SSH directo,
# sin Ansible. Pensado para controladores donde Ansible no corre nativo,
# por ejemplo Windows con Git Bash. Hace lo mismo que el playbook oficial.
#
# Uso: ./install-k3s-ssh.sh <ip1> <ip2> <ip3> <usuario> [fichero-token]
set -euo pipefail

IP1="${1:?Uso: $0 ip1 ip2 ip3 usuario [fichero-token]}"
IP2="${2:?}"; IP3="${3:?}"; USUARIO="${4:?}"
TOKEN_FILE="${5:-k3s-token}"
K3S_VERSION="v1.30.4+k3s1"
TLS_SAN="lab.yosefnaabid.com"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

[ -f "$TOKEN_FILE" ] || openssl rand -hex 16 > "$TOKEN_FILE"
TOKEN=$(cat "$TOKEN_FILE")

instala() {
  local ip="$1"; shift
  echo ">>> k3s en $ip $*"
  ssh $SSH_OPTS "$USUARIO@$ip" \
    "curl -sfL https://get.k3s.io -o /tmp/k3s.sh && sudo env INSTALL_K3S_VERSION='$K3S_VERSION' K3S_TOKEN='$TOKEN' sh /tmp/k3s.sh $*"
}

instala "$IP1" server --cluster-init --tls-san "$TLS_SAN"
echo ">>> esperando a que el primer server levante la API"
sleep 25
instala "$IP2" server --server "https://$IP1:6443" --tls-san "$TLS_SAN"
instala "$IP3" server --server "https://$IP1:6443" --tls-san "$TLS_SAN"

echo ">>> trayendo kubeconfig"
ssh $SSH_OPTS "$USUARIO@$IP1" "sudo cat /etc/rancher/k3s/k3s.yaml" > kubeconfig
sed -i "s/127.0.0.1/$IP1/" kubeconfig
echo "Listo. Prueba con  KUBECONFIG=./kubeconfig kubectl get nodes -o wide"
