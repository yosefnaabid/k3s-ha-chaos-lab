#!/usr/bin/env bash
# SIMULACRO 1. Muere un nodo a las 3 de la manana.
#
# Se ejecuta EN EL ANFITRION Proxmox, o desde tu equipo con
#   ssh root@192.168.1.40 '/root/drill1-node-death.sh 203'
#
# Parada dura del contenedor que aloja el primario de PostgreSQL, sin apagado
# limpio. Equivale a tirar del cable: el nodo no avisa a nadie de que se va.
#
# Antes de lanzarlo, en OTRA terminal, arranca ./monitor.sh
#
# Uso: ./drill1-node-death.sh <vmid-de-la-victima>
#
# Para elegir la victima, mira antes que nodo aloja el primario:
#   kubectl -n database get cluster pg-lab -o jsonpath='{.status.currentPrimary}'
#   kubectl -n database get pods -o wide
# El objetivo es matar el nodo del PRIMARIO, que es el caso peor: obliga a un
# failover de la base de datos ademas de a reprogramar los pods.
set -euo pipefail

VMID="${1:?Uso: $0 <vmid>  (203 si el primario esta en k3s-3)}"

# Los nodos son contenedores LXC, no maquinas virtuales, asi que la herramienta
# es pct y no qm. Un 'pct stop' es una parada dura, que es justo lo que
# queremos: si usaramos 'pct shutdown' el nodo se despediria por las buenas y
# el simulacro no probaria nada.
echo "$(date +%T) Parada dura del contenedor $VMID"
T0=$(date +%s)
pct stop "$VMID"

echo "$(date +%T) Nodo caido. T0 del apagon: $T0 (epoch)"
echo ""
echo "Observa AHORA desde tu equipo, en terminales separadas:"
echo "  kubectl get nodes -w"
echo "  kubectl -n database get cluster pg-lab -w"
echo "  kubectl get pods -A -o wide | grep -v Running"
echo ""
echo "Lo que tiene que pasar:"
echo "  1. El nodo tarda ~40 s en pasar a NotReady (es el node-monitor-grace-period)"
echo "  2. etcd sigue con quorum, 2 de 3, asi que la API nunca deja de responder"
echo "  3. CloudNativePG promociona la replica a primario"
echo "  4. Los pods del nodo muerto se recrean en los otros dos"
echo ""
echo "Cuando el monitor vuelva a dar 200 sostenido, corta el monitor con Ctrl+C"
echo "y apunta el hueco que te imprima."
echo ""
echo "Para cerrar el simulacro, reenciende el nodo:"
echo "  pct start $VMID"
echo "y comprueba que vuelve a Ready:  kubectl get nodes"
