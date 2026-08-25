#!/usr/bin/env bash
# SIMULACRO 2. Despliegue roto un viernes por la tarde.
#
# Publica una version de podinfo que no existe. Lo interesante no es que falle,
# es que NO PASE NADA: la sonda de readiness frena el despliegue progresivo y
# las replicas viejas siguen atendiendo. El usuario no se entera.
#
# El rollback no se hace tocando el cluster, se hace revirtiendo el commit.
# Git es la fuente de la verdad, asi que deshacer en Git es deshacer en produccion.
#
# En otra terminal, arranca ./monitor.sh y dejalo corriendo TODO el ciclo.
# La cifra que buscas en su resumen es CERO segundos de indisponibilidad.
#
# Uso, desde Git Bash en drills/:   ./drill2-broken-deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

REPO_DIR="${1:-$(cd .. && pwd)}"
APP_FILE="cluster/bootstrap/apps/podinfo.yaml"
export PATH="$REPO_DIR/local/bin:$PATH"
export KUBECONFIG="$REPO_DIR/local/kubeconfig"

cd "$REPO_DIR"

echo "=== PASO 1. Romper el despliegue con una etiqueta de imagen inexistente ==="
if grep -q "tag: no-existe" "$APP_FILE"; then
  echo "Ya estaba roto de un intento anterior. Revierte primero con:"
  echo "  git revert --no-edit HEAD && git push"
  exit 1
fi

# Se inserta con awk y no con python, porque en Git Bash sobre Windows no hay
# python3 garantizado y awk si.
awk '
  { print }
  /^        replicaCount: 3$/ {
    print "        image:"
    print "          tag: no-existe"
  }
' "$APP_FILE" > "$APP_FILE.tmp" && mv "$APP_FILE.tmp" "$APP_FILE"

grep -q "tag: no-existe" "$APP_FILE" || { echo "ERROR: no se pudo insertar la etiqueta rota"; exit 1; }
echo "Etiqueta rota escrita en $APP_FILE"

git add "$APP_FILE"
git commit -q -m "drill2: despliegue roto a proposito, etiqueta de imagen inexistente"
git push -q
echo "Commit publicado. ArgoCD lo recogera en menos de 3 minutos."
echo ""

echo "=== PASO 2. Forzar el refresco para no esperar al sondeo ==="
kubectl -n argocd annotate app root argocd.argoproj.io/refresh=hard --overwrite >/dev/null
sleep 5
kubectl -n argocd annotate app podinfo argocd.argoproj.io/refresh=hard --overwrite >/dev/null
echo ""

echo "=== PASO 3. Observa el despliegue BLOQUEADO ==="
echo "Vigilando 90 segundos. Fijate en que las replicas viejas siguen en Running"
echo "mientras las nuevas se atascan en ImagePullBackOff o ErrImagePull."
echo ""
for i in $(seq 1 15); do
  printf "\n--- %s (%d/15) ---\n" "$(date +%T)" "$i"
  kubectl -n podinfo get pods --no-headers 2>/dev/null | awk '{printf "  %-42s %-8s %s\n", $1, $2, $3}'
  SANOS=$(kubectl -n podinfo get pods --no-headers 2>/dev/null | grep -c "Running" || true)
  CODIGO=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 https://app.lab.yosefnaabid.com 2>/dev/null || echo "000")
  printf "  replicas sirviendo: %s   la aplicacion responde: %s\n" "$SANOS" "$CODIGO"
  sleep 6
done

echo ""
echo "=== PASO 4. AQUI SE CAPTURA ==="
echo "Abre ArgoCD y captura la app podinfo: aparecera Progressing o Degraded,"
echo "con los pods nuevos fallando y los viejos sanos al lado."
echo ""
echo "Cuando la tengas, pulsa Enter para revertir."
read -r

echo "=== PASO 5. Rollback como se hace de verdad, revirtiendo el commit ==="
git revert --no-edit HEAD
git push -q
kubectl -n argocd annotate app root argocd.argoproj.io/refresh=hard --overwrite >/dev/null
sleep 5
kubectl -n argocd annotate app podinfo argocd.argoproj.io/refresh=hard --overwrite >/dev/null
echo "Revert publicado. Esperando a que vuelva a 3 de 3."

for i in $(seq 1 30); do
  LISTAS=$(kubectl -n podinfo get deploy podinfo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  TOTAL=$(kubectl -n podinfo get deploy podinfo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 3)
  printf "  [%s] %s/%s listas\n" "$(date +%T)" "${LISTAS:-0}" "$TOTAL"
  [ "${LISTAS:-0}" = "$TOTAL" ] && { echo "  Despliegue sano de nuevo."; break; }
  sleep 10
done

echo ""
echo "=== PASO 6. Corta el monitor con Ctrl+C y guarda su resumen ==="
echo "Indisponibilidad esperada: 0.0 s"
echo "Ese cero es la cifra del simulacro 2."
