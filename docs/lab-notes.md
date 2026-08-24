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
