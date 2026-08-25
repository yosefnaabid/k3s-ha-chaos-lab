# Evidencia del laboratorio

Las 8 capturas del proyecto, en orden de aparicion. Tres de ellas ocurren
DURANTE un simulacro, asi que no se pueden hacer todas el mismo rato: hay que
provocar el incidente y disparar mientras pasa.

| # | Fichero | Que se ve |
|---|---|---|
| 1 | [img/01-proxmox-vms.png](img/01-proxmox-vms.png) | Los 3 nodos corriendo en Proxmox |
| 2 | [img/02-nodes-ready.png](img/02-nodes-ready.png) | kubectl get nodes con los 3 Ready y rol control-plane,etcd,master |
| 3 | [img/03-argocd-tree.png](img/03-argocd-tree.png) | ArgoCD con el arbol de aplicaciones Synced y Healthy |
| 4 | [img/04-app-tls.png](img/04-app-tls.png) | podinfo servido por HTTPS con el certificado de Let's Encrypt abierto |
| 5 | [img/05-grafana-nodes.png](img/05-grafana-nodes.png) | Grafana con los 3 kubelets arriba y sus metricas |
| 6 | [img/06-drill1-notready.png](img/06-drill1-notready.png) | DURANTE el simulacro 1: un nodo NotReady, PostgreSQL promocionando la replica, pods recolocandose y la aplicacion devolviendo 200 |
| 7 | [img/07-drill3-hpa.png](img/07-drill3-hpa.png) | DURANTE el simulacro 3: replicas de 3 a 6 y vuelta, con la latencia plana |
| 8 | [img/08-drill4-stopwatch.png](img/08-drill4-stopwatch.png) | Al terminar el simulacro 4: la cronologia completa y el tiempo total de recuperacion |
| extra | [img/09-drill2-rollout-bloqueado.png](img/09-drill2-rollout-bloqueado.png) | DURANTE el simulacro 2: las replicas nuevas en ImagePullBackOff mientras las viejas siguen sirviendo |

Las capturas de terminal se generan con
[local/render-captura.sh](../local/render-captura.sh) y las de navegador con
[local/captura-web.py](../local/captura-web.py). El contenido es salida real
del cluster, las herramientas solo la maquetan, y asi la evidencia se puede
regenerar en cualquier momento en lugar de depender de que alguien tuviera la
pantalla abierta en el instante justo.

## Cifras medidas

Todas tomadas el 25 de agosto de 2026, sobre Proxmox anidado en un Ryzen 5 2600
con 3 nodos LXC de 4 GB y 3 nucleos cada uno.

| Metrica | Valor |
|---|---|
| Peticiones perdidas al matar un nodo | 1 de 4315 sondeos, un unico hueco de 2,7 s |
| Deteccion del nodo muerto | 40 s hasta NotReady |
| Failover de PostgreSQL | automatico, sin intervencion; el primario paso de pg-lab-1 a pg-lab-2 |
| Recolocacion de los pods del nodo muerto | 300 s, que es la tolerancia por defecto a not-ready |
| Downtime del despliegue roto | 0,0 s en 3437 sondeos |
| Vuelta atras del despliegue roto | 20 s desde el git revert hasta 3 de 3 replicas sanas |
| Carga soportada | 924512 peticiones, 3081 por segundo, 0 fallos |
| Latencia p95 durante el pico | 22,34 ms de extremo a extremo, 4,75 ms dentro de la aplicacion |
| Tiempo de 3 a 6 replicas | 40 s desde que empieza la carga |
| Vuelta de 6 a 3 replicas | ~6 min tras cesar la carga, por la ventana de estabilizacion del HPA |
| Reconstruccion total desde Git y copias | 9 min 37 s |

### Desglose de la reconstruccion total

| Hito | Tiempo |
|---|---|
| terraform destroy de los 3 nodos | +0 s |
| Nodos recreados | +58 s |
| Contenedores preparados para k3s | +88 s |
| Los 3 nodos responden por SSH | +142 s |
| k3s instalado en alta disponibilidad | +249 s |
| ArgoCD arriba | +334 s |
| Secretos recreados, Git toma el control | +337 s |
| podinfo sirviendo trafico | +514 s |
| Certificado de Let's Encrypt emitido | +525 s |
| PostgreSQL replicado y sano | +577 s |

## Lo que no salio a la primera

La tabla de arriba es de la segunda pasada. La primera sirvio para descubrir,
que es exactamente para lo que estan los simulacros. Lo que fallo:

- **El simulacro 3 no escalaba nada.** El script de carga pegaba a `/delay/1`,
  que suena a carga pero solo duerme. El HPA de este laboratorio escala por CPU
  y un proceso dormido no gasta CPU: 80 usuarios dejaban los pods a 3 milicores.
  Cambiado a `/api/info`, que si serializa una respuesta, los pods suben a entre
  200 y 550 milicores y el autoescalado reacciona.

- **El simulacro 4 se colgaba esperando SSH.** Los nodos recreados traen claves
  de host nuevas y `StrictHostKeyChecking=accept-new` acepta hosts desconocidos,
  no hosts cambiados. Abortaba con REMOTE HOST IDENTIFICATION HAS CHANGED y el
  bucle de espera no terminaba nunca.

- **El simulacro 4 no instalaba ArgoCD.** El CRD `applicationsets.argoproj.io`
  pasa de los 262144 bytes que admite una anotacion de Kubernetes, y un apply
  del lado cliente guarda el manifiesto entero en
  `last-applied-configuration`. Se arregla con `--server-side`.

- **La restauracion no encontraba el pod.** En Git Bash sobre Windows, MSYS
  reescribe cualquier argumento con pinta de ruta unix antes de pasarlo a un
  `.exe`, asi que `database/pg-lab-1:/tmp/restore.sql` acababa convertido en una
  ruta de Windows. Ahora el dump entra por la entrada estandar.

## Un limite honesto: MetalLB en modo L2

MetalLB anuncia la IP del servicio desde UN solo nodo. Los eventos del cluster
lo dejan ver:

```
announcing from node "k3s-3" with protocol "layer2"
announcing from node "k3s-1" with protocol "layer2"
```

Eso significa que el resultado del simulacro 1 depende de a quien mates. Si cae
un nodo cualquiera, no se pierde ni una peticion. Si cae el que esta anunciando,
hay un hueco hasta que otro speaker toma el relevo, y ese hueco es el unico
fallo que aparece en los 4315 sondeos. En una red con BGP de verdad esto se
resuelve con ECMP y varios anuncios simultaneos, pero eso ya no cabe en un
laboratorio detras de un router domestico. Queda anotado como lo que es, un
limite del montaje y no un fallo de Kubernetes.
