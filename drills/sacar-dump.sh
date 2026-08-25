#!/usr/bin/env bash
# Saca una copia de la base de datos FUERA del cluster.
#
# Se lanza desde Git Bash, en drills/:   ./sacar-dump.sh
#
# El CronJob nocturno deja sus dumps en un PVC, que esta muy bien para el dia a
# dia pero no sirve para el simulacro 4: ese PVC vive dentro de lo que vamos a
# destruir. Una copia que muere con el sistema que respalda no es una copia.
#
# Aqui el dump sale por stdout y aterriza en tu equipo, que es el unico sitio
# que va a sobrevivir al terraform destroy.
set -euo pipefail
cd "$(dirname "$0")"

REPO_DIR="$(cd .. && pwd)"
export PATH="$REPO_DIR/local/bin:$PATH"
export KUBECONFIG="$REPO_DIR/local/kubeconfig"

DESTINO="${1:-$REPO_DIR/local/labdb-$(date +%Y%m%d-%H%M%S).sql}"

echo ">>> Buscando el primario"
PRIMARIO=$(kubectl -n database get pod -l cnpg.io/instanceRole=primary -o jsonpath='{.items[0].metadata.name}')
echo "    primario: $PRIMARIO"

echo ">>> Leyendo la clave que genero el operador"
PASS=$(kubectl -n database get secret pg-lab-app -o jsonpath='{.data.password}' | base64 -d)

echo ">>> Volcando labdb"
kubectl -n database exec "$PRIMARIO" -- \
  env PGPASSWORD="$PASS" pg_dump -h pg-lab-rw -U lab -d labdb --clean --if-exists \
  > "$DESTINO"

LINEAS=$(wc -l < "$DESTINO")
TAM=$(du -h "$DESTINO" | cut -f1)
echo ""
echo "Copia guardada en: $DESTINO"
echo "  $LINEAS lineas, $TAM"
echo ""
echo "Comprobacion rapida de que no esta vacia:"
grep -cE "^(CREATE TABLE|COPY|INSERT)" "$DESTINO" | sed 's/^/  sentencias de datos y esquema: /'
echo ""
echo "Ya puedes lanzar el simulacro 4:"
echo "  ./drill4-total-loss.sh $DESTINO"
