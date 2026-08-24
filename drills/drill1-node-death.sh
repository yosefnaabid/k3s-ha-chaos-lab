#!/usr/bin/env bash
# SIMULACRO 1. Muere un nodo a las 3 de la manana.
# Se ejecuta DESDE EL HIPERVISOR Proxmox (o via ssh root@proxmox desde tu equipo).
# Parada dura de la VM que aloja el primario de PostgreSQL, sin apagado limpio.
#
# En otra terminal, ANTES de lanzar esto, arranca ./monitor.sh
#
# Uso: ./drill1-node-death.sh <vmid-de-la-victima>
set -euo pipefail

VMID="${1:?Uso: $0 <vmid>  (mira antes que nodo aloja el primario: kubectl -n database get pods -o wide)}"

echo "$(date +%T) Parada dura del VMID $VMID"
T0=$(date +%s)
qm stop "$VMID"

echo "$(date +%T) VM parada. Ahora observa desde tu equipo:"
echo "  watch kubectl get nodes"
echo "  watch kubectl get pods -A -o wide"
echo "  kubectl -n database get cluster pg-lab   (failover del primario)"
echo ""
echo "Cuando el monitor vuelva a dar 200 sostenido, apunta los segundos."
echo "Para cerrar el simulacro, reenciende el nodo y comprueba que vuelve a Ready:"
echo "  qm start $VMID"
echo ""
echo "T0 del apagon: $T0 (epoch) — cruzalo con el log del monitor"
