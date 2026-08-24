#!/usr/bin/env bash
# SIMULACRO 4. Perdida total del cluster, cronometrada de principio a fin.
#
# Destruye las TRES VMs con el cluster vivo y lo reconstruye todo desde codigo,
# Git y la ultima copia de la base de datos. La cifra final es el titular del
# proyecto: cuantos minutos tarda en volver TODO.
#
# REQUISITO PREVIO: haber copiado el ultimo pg_dump FUERA del cluster
# (el CronJob nocturno lo deja en el PVC pg-dumps, sacalo antes con
#  kubectl cp o apunta el PVC a tu NFS). El fichero se pasa como argumento.
#
# Uso: ./drill4-total-loss.sh <ruta-al-repo> <ruta-al-dump.sql>
set -euo pipefail

REPO_DIR="${1:?Uso: $0 <ruta-al-repo> <dump.sql>}"
DUMP="${2:?Falta la ruta al dump.sql sacado ANTES de destruir}"
LOG="drill4-$(date +%Y%m%d-%H%M%S).log"

marca() { echo "[$(date +%T)] [+$((($(date +%s) - T0)))s] $*" | tee -a "$LOG"; }

echo "=== SIMULACRO 4: PERDIDA TOTAL ===" | tee "$LOG"
T0=$(date +%s)

marca "FASE A. terraform destroy de las 3 VMs con el cluster vivo"
( cd "$REPO_DIR/terraform" && terraform destroy -auto-approve ) >>"$LOG" 2>&1
marca "Las 3 VMs ya no existen"

marca "FASE B. terraform apply, vuelven las VMs limpias"
( cd "$REPO_DIR/terraform" && terraform apply -auto-approve ) >>"$LOG" 2>&1
marca "VMs recreadas, esperando SSH"
sleep 30

marca "FASE C. Ansible reinstala k3s en alta disponibilidad"
( cd "$REPO_DIR/ansible" && ansible-playbook k3s-ansible/playbooks/site.yml -i inventory.yml ) >>"$LOG" 2>&1
marca "k3s instalado, trayendo kubeconfig"
NODO1=$(cd "$REPO_DIR/terraform" && terraform output -json node_ips | python3 -c 'import sys,json; print(list(json.load(sys.stdin).values())[0])')
scp -o StrictHostKeyChecking=accept-new "admin@$NODO1:/etc/rancher/k3s/k3s.yaml" ./kubeconfig.drill4 >>"$LOG" 2>&1
sed -i "s/127.0.0.1/$NODO1/" ./kubeconfig.drill4
export KUBECONFIG=$PWD/kubeconfig.drill4

marca "FASE D. ArgoCD y la app raiz, Git reconstruye el resto solo"
kubectl create namespace argocd >>"$LOG" 2>&1
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >>"$LOG" 2>&1
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s >>"$LOG" 2>&1
kubectl apply -n argocd -f "$REPO_DIR/cluster/bootstrap/root-app.yaml" >>"$LOG" 2>&1
marca "Root app aplicada. Recreando el secreto de Cloudflare (unico paso manual)"
echo ">>> Ejecuta ahora en otra terminal el kubectl create secret de docs/setup-secrets.md y pulsa enter"
read -r

marca "FASE E. Esperando a que todo este Healthy"
until kubectl -n database get cluster pg-lab -o jsonpath='{.status.readyInstances}' 2>/dev/null | grep -q 2; do
  sleep 15; marca "  esperando PostgreSQL"
done
marca "PostgreSQL arriba. Restaurando el dump"
kubectl -n database cp "$DUMP" "$(kubectl -n database get pod -l cnpg.io/instanceRole=primary -o name | cut -d/ -f2):/tmp/restore.sql" >>"$LOG" 2>&1
kubectl -n database exec "$(kubectl -n database get pod -l cnpg.io/instanceRole=primary -o name)" -- psql -U postgres -d labdb -f /tmp/restore.sql >>"$LOG" 2>&1
marca "Datos restaurados"

marca "FASE F. Esperando el 200 de la aplicacion"
until [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 https://app.lab.yosefnaabid.com)" = "200" ]; do
  sleep 10; marca "  esperando a la app"
done

TOTAL=$((($(date +%s) - T0)))
marca "RECONSTRUCCION COMPLETA. El cluster entero ha vuelto de Git y de las copias"
echo "" | tee -a "$LOG"
printf "TIEMPO TOTAL DE RECUPERACION %dm %02ds\n" $((TOTAL/60)) $((TOTAL%60)) | tee -a "$LOG"
echo "Esta pantalla es la captura 8 del proyecto." | tee -a "$LOG"
