#!/usr/bin/env bash
# SIMULACRO 2. Despliegue roto un viernes por la tarde.
# Publica una version de podinfo que no existe. La readiness probe frena el
# rollout y las replicas viejas siguen sirviendo. El rollback es un revert en Git.
#
# En otra terminal, arranca ./monitor.sh y dejalo corriendo todo el ciclo.
# La cifra que buscas en su resumen final es CERO segundos de indisponibilidad.
set -euo pipefail

REPO_DIR="${1:?Uso: $0 <ruta-a-tu-clon-del-repo>}"
APP_FILE="cluster/bootstrap/apps/podinfo.yaml"

cd "$REPO_DIR"

echo "Paso 1. Romper el despliegue con una etiqueta de imagen inexistente"
python3 - "$APP_FILE" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
if 'tag: no-existe' not in s:
    s = s.replace("replicaCount: 3",
                  "replicaCount: 3\n        image:\n          tag: no-existe")
    open(p, 'w').write(s)
    print("values rotos escritos en", p)
else:
    print("ya estaba roto de un intento anterior")
PY

git add "$APP_FILE"
git commit -m "drill2 despliegue roto a proposito"
git push

echo ""
echo "Paso 2. Observa el rollout BLOQUEADO mientras las replicas viejas siguen vivas:"
echo "  kubectl -n podinfo get pods            (ImagePullBackOff en las nuevas)"
echo "  kubectl -n podinfo rollout status deploy/podinfo --timeout=90s || true"
echo "Captura la vista de ArgoCD con la app en Progressing y las replicas sanas."
echo ""
echo "Paso 3. Rollback como se hace de verdad, con un revert:"
echo "  git revert --no-edit HEAD && git push"
echo ""
echo "Paso 4. Corta el monitor y guarda su resumen. Indisponibilidad esperada 0.0 s"
