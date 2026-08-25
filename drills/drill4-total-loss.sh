#!/usr/bin/env bash
# SIMULACRO 4. Perdida total del cluster, cronometrada de principio a fin.
#
# Destruye los TRES nodos con el cluster vivo y lo reconstruye entero desde
# codigo, Git y la ultima copia de la base de datos. La cifra final es el
# titular del proyecto: cuantos minutos tarda en volver TODO.
#
# Se lanza desde Git Bash, en el directorio local/ del repo:
#   ./drill4-total-loss.sh <ruta-al-dump.sql>
#
# REQUISITO PREVIO INNEGOCIABLE
#   Tener el dump FUERA del cluster. Si el unico respaldo vive dentro de lo que
#   vas a destruir, no es un respaldo. Sacalo antes con:
#     ./sacar-dump.sh
#
# Lo unico que NO vuelve solo son dos secretos, y esta bien que sea asi:
#   - el token de Cloudflare, que nunca debe estar en un repo publico
#   - el CRD Pooler de CloudNativePG, que pasa del limite de kubectl apply
# El script se para y te los pide.
set -euo pipefail
cd "$(dirname "$0")"

DUMP="${1:?Uso: $0 <ruta-al-dump.sql>   (sacalo antes con ./sacar-dump.sh)}"
[ -f "$DUMP" ] || { echo "No existe el dump: $DUMP"; exit 1; }
DUMP="$(cd "$(dirname "$DUMP")" && pwd)/$(basename "$DUMP")"

REPO_DIR="$(cd .. && pwd)"
LOCAL_DIR="$REPO_DIR/local"
export PATH="$LOCAL_DIR/bin:$PATH"
export KUBECONFIG="$LOCAL_DIR/kubeconfig"

LLAVE=~/.ssh/id_pve01_lab
PVE=192.168.1.40
IPS=(192.168.1.61 192.168.1.62 192.168.1.63)
VMIDS=(201 202 203)
APP=https://app.lab.yosefnaabid.com
LOG="$LOCAL_DIR/drill4-$(date +%Y%m%d-%H%M%S).log"
SSH="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o IdentitiesOnly=yes -i $LLAVE"

marca() { printf "[%s] [+%03ds] %s\n" "$(date +%T)" "$(( $(date +%s) - T0 ))" "$*" | tee -a "$LOG"; }

echo "=== SIMULACRO 4: PERDIDA TOTAL ===" | tee "$LOG"
echo "Dump de partida: $DUMP" | tee -a "$LOG"
T0=$(date +%s)

marca "FASE A. terraform destroy, se van los 3 nodos con el cluster vivo"
( cd "$REPO_DIR/terraform" && terraform destroy -auto-approve ) >>"$LOG" 2>&1
marca "Los 3 nodos ya no existen"

marca "FASE B. terraform apply, vuelven limpios"
( cd "$REPO_DIR/terraform" && terraform apply -auto-approve ) >>"$LOG" 2>&1
marca "Nodos recreados"

marca "FASE C. Preparando los LXC para k3s (apparmor, cgroups, kmsg)"
$SSH "root@$PVE" 'bash -s' -- "${VMIDS[@]}" < "$REPO_DIR/scripts/prepare-lxc.sh" >>"$LOG" 2>&1
marca "Contenedores preparados, reiniciandolos para que tome la config"
for id in "${VMIDS[@]}"; do
  $SSH "root@$PVE" "pct stop $id || true; sleep 2; pct start $id" >>"$LOG" 2>&1
done

# Los nodos son nuevos y tienen claves de host nuevas, pero known_hosts guarda
# las de los que acabamos de destruir. StrictHostKeyChecking=accept-new acepta
# hosts DESCONOCIDOS, no hosts CAMBIADOS: ante una clave distinta aborta con
# REMOTE HOST IDENTIFICATION HAS CHANGED y el bucle de espera no termina nunca.
marca "Olvidando las claves SSH de los nodos destruidos"
for ip in "${IPS[@]}"; do ssh-keygen -R "$ip" >/dev/null 2>&1 || true; done

marca "Esperando SSH en los tres nodos"
for ip in "${IPS[@]}"; do
  until $SSH -o BatchMode=yes "root@$ip" true 2>/dev/null; do sleep 5; done
  marca "  $ip responde"
done

marca "FASE D. Instalando k3s en alta disponibilidad"
# La plantilla Debian minima no trae curl, y el instalador lo necesita
for ip in "${IPS[@]}"; do
  $SSH "root@$ip" "command -v curl >/dev/null || (apt-get update -qq && apt-get install -y -qq curl)" >>"$LOG" 2>&1
done
( cd "$LOCAL_DIR" && IDENTITY="$LLAVE" "$REPO_DIR/scripts/install-k3s-ssh.sh" "${IPS[@]}" root ) >>"$LOG" 2>&1
marca "k3s instalado en los 3 nodos"
kubectl get nodes -o wide 2>&1 | tee -a "$LOG"

marca "FASE E. ArgoCD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >>"$LOG" 2>&1
# --server-side no es opcional aqui. El CRD applicationsets.argoproj.io pasa de
# los 262144 bytes que admite una anotacion, y un apply del lado cliente guarda
# el manifiesto entero en kubectl.kubernetes.io/last-applied-configuration, asi
# que revienta. Con server-side apply no hay tal anotacion. Es el mismo problema
# que tienen los CRD de CloudNativePG, ver docs/lab-notes.md
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >>"$LOG" 2>&1
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=600s >>"$LOG" 2>&1
marca "ArgoCD arriba"

marca "FASE F. Los dos pasos manuales por diseno"
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml >>"$LOG" 2>&1
marca "  CRD de CloudNativePG instalados con server-side apply"
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f - >>"$LOG" 2>&1

# El token sigue sin estar en Git, pero tampoco hace falta pararse a teclearlo:
# se guarda una vez en local/, que el .gitignore excluye, y de ahi se recrea el
# secreto. Si el fichero no esta, el simulacro se para y lo pide, como antes.
TOKEN_CF="$LOCAL_DIR/cloudflare-token.txt"
if [ -s "$TOKEN_CF" ]; then
  kubectl -n cert-manager create secret generic cloudflare-api-token \
    --from-literal=api-token="$(cat "$TOKEN_CF")" \
    --dry-run=client -o yaml | kubectl apply -f - >>"$LOG" 2>&1
  marca "  Secreto de Cloudflare recreado desde local/cloudflare-token.txt"
else
  echo ""
  echo ">>> No encuentro $TOKEN_CF"
  echo "    Pega AHORA en otra terminal el secreto de Cloudflare"
  echo "    (docs/setup-secrets.md) y pulsa Enter aqui cuando este creado."
  read -r
  marca "  Secreto de Cloudflare confirmado a mano"
fi

marca "FASE G. Root app. A partir de aqui Git reconstruye el resto solo"
kubectl apply -n argocd -f "$REPO_DIR/cluster/bootstrap/root-app.yaml" >>"$LOG" 2>&1

marca "Esperando a que PostgreSQL tenga sus 2 instancias"
until [ "$(kubectl -n database get cluster pg-lab -o jsonpath='{.status.readyInstances}' 2>/dev/null)" = "2" ]; do
  sleep 15; marca "  esperando PostgreSQL"
done
marca "PostgreSQL en alta disponibilidad"

marca "FASE H. Restaurando los datos desde la copia"
PRIMARIO=$(kubectl -n database get pod -l cnpg.io/instanceRole=primary -o jsonpath='{.items[0].metadata.name}')
kubectl -n database cp "$DUMP" "$PRIMARIO:/tmp/restore.sql" >>"$LOG" 2>&1
kubectl -n database exec "$PRIMARIO" -- psql -U postgres -d labdb -f /tmp/restore.sql >>"$LOG" 2>&1
marca "Datos restaurados en $PRIMARIO"

marca "FASE I. Esperando el 200 de la aplicacion"
until [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$APP" 2>/dev/null)" = "200" ]; do
  sleep 10; marca "  esperando a la app"
done

TOTAL=$(( $(date +%s) - T0 ))
marca "RECONSTRUCCION COMPLETA"
echo "" | tee -a "$LOG"
echo "================================================" | tee -a "$LOG"
printf "  TIEMPO TOTAL DE RECUPERACION  %dm %02ds\n" $((TOTAL/60)) $((TOTAL%60)) | tee -a "$LOG"
echo "================================================" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "  3 nodos, k3s en HA, 10 aplicaciones, PostgreSQL" | tee -a "$LOG"
echo "  replicado y los datos de vuelta. Todo desde Git." | tee -a "$LOG"
echo "  Log completo en $LOG" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "Esta pantalla es la captura 8 del proyecto." | tee -a "$LOG"
