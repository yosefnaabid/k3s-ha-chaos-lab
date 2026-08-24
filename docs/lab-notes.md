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
