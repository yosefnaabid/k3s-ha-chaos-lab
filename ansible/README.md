# Instalacion de k3s en alta disponibilidad

Se usa el playbook oficial del proyecto k3s. No lo reinvento porque mantenerlo ya lo hace la CNCF.

```bash
git clone https://github.com/k3s-io/k3s-ansible
cp inventory.yml.example inventory.yml
# edita inventory.yml con tus IPs, tu usuario y un token nuevo
ansible-playbook k3s-ansible/playbooks/site.yml -i inventory.yml
```

Al terminar, trae el kubeconfig a tu equipo y apunta al primer nodo.

```bash
scp admin@10.0.10.11:/etc/rancher/k3s/k3s.yaml ./kubeconfig
sed -i 's/127.0.0.1/10.0.10.11/' kubeconfig
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes -o wide
```

Los tres nodos deben aparecer en Ready con los roles control-plane, etcd y master. Esa salida es la captura 2 del proyecto.

La version de k3s va fijada en el inventario a proposito. Un laboratorio sin versiones fijadas se rompe solo a los tres meses.
