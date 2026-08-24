#!/usr/bin/env bash
# Vigilante de disponibilidad. Corre en una terminal aparte durante CUALQUIER simulacro.
# Registra cada medio segundo el codigo HTTP y al cortar con Ctrl+C imprime el resumen
# con los huecos de indisponibilidad detectados y su duracion total.
set -euo pipefail

URL="${1:-https://app.lab.yosefnaabid.com}"
LOG="${2:-monitor-$(date +%Y%m%d-%H%M%S).log}"

echo "Vigilando $URL cada 0.5s. Log en $LOG. Ctrl+C para parar y ver el resumen."

resumen() {
  echo ""
  echo "===== RESUMEN ====="
  awk '
    $2 != "200" && !hueco { inicio=$1; hueco=1 }
    $2 == "200" && hueco  { printf "Hueco de %.1f s (de %s a %s)\n", $1-inicio, inicio, $1; total+=$1-inicio; hueco=0 }
    END {
      if (hueco) printf "Hueco ABIERTO desde %s\n", inicio
      printf "Indisponibilidad total acumulada %.1f s\n", total+0
    }' "$LOG"
  exit 0
}
trap resumen INT

while true; do
  ts=$(date +%s.%3N)
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$URL" || echo "000")
  echo "$ts $code" | tee -a "$LOG" | grep -v " 200$" || true
  sleep 0.5
done
