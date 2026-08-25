#!/usr/bin/env bash
# Deja la terminal lista para los simulacros.
#
# Se CARGA, no se ejecuta, porque tiene que modificar la sesion actual:
#   . ./entorno.sh
#
# Los scripts de simulacro se apanan solos, esto es para los bucles de
# observacion que se escriben a mano durante los simulacros.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$REPO_DIR/local/kubeconfig"
export PATH="$REPO_DIR/local/bin:$PATH"

echo "Entorno listo."
echo "  kubectl:    $(command -v kubectl || echo 'NO ENCONTRADO')"
echo "  kubeconfig: $KUBECONFIG"
kubectl get nodes --no-headers 2>/dev/null | awk '{printf "  nodo %-8s %s\n", $1, $2}' \
  || echo "  AVISO: el cluster no responde"
