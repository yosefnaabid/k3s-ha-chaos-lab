#!/usr/bin/env bash
# Siembra labdb con datos reales del laboratorio.
#
# Sin esto el simulacro 4 no demuestra nada: restaurar una base de datos vacia
# es restaurar nada. La tabla guarda el registro de los propios simulacros, asi
# que despues de la perdida total puedes consultarla y ver que las filas que
# escribiste ANTES de destruir el cluster siguen ahi.
#
# Uso, desde Git Bash en drills/:   ./seed-datos.sh
set -euo pipefail
cd "$(dirname "$0")"

REPO_DIR="$(cd .. && pwd)"
export PATH="$REPO_DIR/local/bin:$PATH"
export KUBECONFIG="$REPO_DIR/local/kubeconfig"

PRIMARIO=$(kubectl -n database get pod -l cnpg.io/instanceRole=primary -o jsonpath='{.items[0].metadata.name}')
PASS=$(kubectl -n database get secret pg-lab-app -o jsonpath='{.data.password}' | base64 -d)

echo ">>> Creando el esquema en $PRIMARIO"
kubectl -n database exec -i "$PRIMARIO" -- \
  env PGPASSWORD="$PASS" psql -h pg-lab-rw -U lab -d labdb <<'SQL'
CREATE TABLE IF NOT EXISTS incidentes (
  id          serial PRIMARY KEY,
  simulacro   text        NOT NULL,
  incidente   text        NOT NULL,
  resultado   text,
  registrado  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS nodos (
  nombre    text PRIMARY KEY,
  vmid      int  NOT NULL,
  ip        inet NOT NULL,
  rol       text NOT NULL
);

TRUNCATE nodos;
INSERT INTO nodos (nombre, vmid, ip, rol) VALUES
  ('k3s-1', 201, '192.168.1.61', 'control-plane,etcd,master'),
  ('k3s-2', 202, '192.168.1.62', 'control-plane,etcd,master'),
  ('k3s-3', 203, '192.168.1.63', 'control-plane,etcd,master');

INSERT INTO incidentes (simulacro, incidente, resultado) VALUES
  ('00-alta', 'Cluster desplegado desde cero con Terraform, k3s y ArgoCD', 'operativo'),
  ('00-alta', 'Migracion de maquinas virtuales a contenedores LXC por latencia de etcd', 'resuelto'),
  ('00-alta', 'Prometheus en bucle de OOM al reproducir el WAL con 640Mi', 'resuelto')
ON CONFLICT DO NOTHING;

SELECT count(*) AS filas_incidentes FROM incidentes;
SELECT count(*) AS filas_nodos FROM nodos;
SQL

echo ""
echo ">>> Comprobando que la replica tambien los tiene"
kubectl -n database exec "$PRIMARIO" -- \
  env PGPASSWORD="$PASS" psql -h pg-lab-ro -U lab -d labdb -t \
  -c "SELECT 'la replica ve ' || count(*) || ' incidentes' FROM incidentes;"

echo ""
echo "Datos sembrados. Ahora saca la copia:  ./sacar-dump.sh"
