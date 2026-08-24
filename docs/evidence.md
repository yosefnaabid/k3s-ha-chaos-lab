# Evidencia del laboratorio

Las 8 capturas del proyecto, en orden de aparicion. Cada una tiene su momento exacto, no se pueden hacer todas el mismo dia porque tres de ellas ocurren DURANTE los simulacros. Nombres de fichero ya decididos para que el README y el portfolio las referencien sin tocar nada.

| # | Fichero | Que se ve | Cuando y donde |
|---|---|---|---|
| 1 | img/01-proxmox-vms.png | Las 3 VMs k3s corriendo en Proxmox | Tras fase 0, vista Datacenter del panel de Proxmox |
| 2 | img/02-nodes-ready.png | kubectl get nodes con 3 Ready y roles control-plane etcd | Tras fase 1, tu terminal |
| 3 | img/03-argocd-tree.png | ArgoCD con todas las apps Synced y Healthy | Tras fase 2, la UI de ArgoCD |
| 4 | img/04-app-tls.png | podinfo respondiendo con el candado del certificado valido | Tras fase 2, navegador en la app con el certificado abierto |
| 5 | img/05-grafana-nodes.png | Dashboard de nodos con los 3 y sus metricas | Tras fase 3, Grafana |
| 6 | img/06-drill1-notready.png | Un nodo NotReady y los pods reprogramados en los otros | DURANTE el simulacro 1, terminal con kubectl get nodes y get pods -o wide |
| 7 | img/07-drill3-hpa.png | Grafica de replicas subiendo de 3 a 6 con la latencia estable | DURANTE el simulacro 3, Grafana |
| 8 | img/08-drill4-stopwatch.png | La pantalla final del drill4 con TIEMPO TOTAL DE RECUPERACION | Al terminar el simulacro 4, terminal |

## Cifras medidas

| Metrica | Valor | Fecha |
|---|---|---|
| Degradacion al morir un nodo | pendiente | |
| Failover de PostgreSQL | pendiente | |
| Downtime del despliegue roto | pendiente | |
| Tiempo de 3 a 6 replicas | pendiente | |
| Latencia p95 durante el pico | pendiente | |
| Reconstruccion total desde Git y copias | pendiente | |
