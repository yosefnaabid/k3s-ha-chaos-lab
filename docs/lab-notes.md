# Notas de ejecucion del laboratorio

Aprendizajes reales al desplegar sobre Proxmox anidado en VirtualBox.

## DNS de los nodos

Las VMs Debian cloud usan systemd-resolved y /etc/resolv.conf es un symlink a
/run/systemd/resolve/resolv.conf. Escribir /etc/resolv.conf a mano NO persiste.
Si el gateway de tu red no resuelve DNS, los pulls de imagenes de containerd
fallan con "lookup registry-1.docker.io: Try again". Fija un resolver real asi:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
printf "[Resolve]\nDNS=1.1.1.1 8.8.8.8\nDomains=~.\n" | sudo tee /etc/systemd/resolved.conf.d/dns.conf
sudo systemctl restart systemd-resolved
```

## Virtualizacion anidada

Proxmox corriendo dentro de VirtualBox necesita nested-hw-virt activado en la VM
de VirtualBox. Los clones de plantilla y arranques van lentos (disco), cuenta con
minutos por VM. Funciona, pero es un laboratorio, no produccion.

## ArgoCD

Instalar con `kubectl apply --server-side` para evitar el error de anotacion
demasiado larga en el CRD applicationsets.

## Dimensionado en hardware modesto

Medido en un Ryzen 5 2600 (6 nucleos) con Proxmox anidado en VirtualBox. Tres
nodos server de k3s significan tres planos de control completos (apiserver,
etcd, scheduler, controller manager) y eso satura la CPU. El sintoma no es
memoria sino tiempo de KERNEL: con vmstat se ve sy al 70 u 80 por ciento y wa
casi a cero, que es la penalizacion de la virtualizacion anidada.

Lo que ayuda, por orden de efecto:

1. Dar mas vCPUs a la VM que aloja Proxmox, sin pasar de los hilos del anfitrion.
2. Apagar lo que no usas de ArgoCD, que por defecto trae SSO, notificaciones y
   applicationsets: `kubectl -n argocd scale deploy/argocd-dex-server
   deploy/argocd-notifications-controller deploy/argocd-applicationset-controller
   --replicas=0`
3. Poner limites de recursos al stack de Prometheus y bajar retencion y
   frecuencia de scrapeo, como esta en cluster/bootstrap/apps/monitoring.yaml
4. Arrancar los nodos escalonados en lugar de los tres a la vez.

Lo que NO hay que hacer es bajar de tres servers a uno. La alta disponibilidad
es el corazon del laboratorio y sin quorum de etcd el simulacro 1 no demuestra
nada.

## etcd y la latencia de disco, el problema que mas cuesta ver

El sintoma era que el apiserver devolvia ServiceUnavailable y los nodos
entraban y salian de NotReady sin patron claro. La causa estaba en el log de
k3s, en avisos de etcd que es facil pasar por alto:

```
{"level":"warn","caller":"v3rpc/interceptor.go:197","msg":"request stats",
 "time spent":"998.272477ms","response type":"/etcdserverpb.KV/Txn"}
```

Casi un segundo para una sola escritura. Lo normal es menos de diez
milisegundos. Con esa latencia, cada miembro de etcd cree que los otros dos
han muerto, empieza una eleccion de lider, y el cluster entra en un bucle del
que no sale.

Lo que NO lo arreglo, aunque parezca lo obvio:

- Poner cache=writeback, ssd=1 e iothread=1 en los discos de las VMs. La
  latencia siguio igual, asi que el cuello de botella no era el disco.
- Mas memoria. Los nodos tenian casi dos gigas libres.

Lo que si lo arreglo fue asumir que el almacenamiento es lento y decirle a
etcd que sea paciente, con el fichero ansible/k3s-config.yaml.example. Sigue
escribiendo lento, pero deja de tumbarse solo.

La leccion util: cuando un cluster de Kubernetes se comporta de forma erratica
sin una causa evidente, mira la latencia de escritura de etcd antes que nada.

## De maquinas virtuales a contenedores LXC, el cambio que lo arreglo

Con los nodos como maquinas virtuales el cluster no se sostenia. El motivo de
fondo era la virtualizacion anidada: Proxmox ya corria dentro de otro
hipervisor, y meter tres VMs mas encima significaba una segunda capa de
traduccion para cada operacion privilegiada. Se veia en vmstat, con el tiempo
de kernel al setenta por ciento y la espera de disco a cero.

Un contenedor LXC comparte el kernel del anfitrion, asi que esa segunda capa
desaparece. Mismo cluster, mismos tres planos de control, misma alta
disponibilidad, pero sin el impuesto.

Numeros del antes y el despues, en el mismo equipo:

| | Con VMs | Con LXC |
|---|---|---|
| Carga del hipervisor | 8 a 10 | 3,5 |
| RAM libre de 12 GB | 2,2 GB | 8,9 GB |
| Desplegar tres replicas | fallaba con etcdserver leader changed | funciona |
| Respuesta de la aplicacion | no llegaba a arrancar | 3 a 5 ms |

Lo que hay que saber para correr k3s dentro de LXC:

- El contenedor tiene que ser privilegiado, con nesting y keyctl activados.
- Hay que quitarle el perfil de apparmor y no descartarle capacidades, o no
  puede montar cgroups.
- k3s aborta si no encuentra /dev/kmsg, que en un contenedor no existe. Se
  resuelve apuntandolo a /dev/console con un servicio que lo rehaga en cada
  arranque.
- El swap del contenedor debe ser cero.
- Los modulos overlay y br_netfilter se cargan en el anfitrion, porque el
  kernel es compartido.

Todo eso esta automatizado en scripts/prepare-lxc.sh
