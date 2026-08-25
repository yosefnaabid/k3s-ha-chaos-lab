# Tarjeta para yosefnaabid.com

Contenido listo para la tarjeta del portfolio, en el mismo tono que las demas.
Cifras medidas el 25 de agosto de 2026, no estimadas. El desglose completo esta
en [evidence.md](evidence.md).

---

**Titulo**
Cluster Kubernetes que sobrevive a la muerte de un nodo

**Linea corta**
Tres nodos con etcd en alta disponibilidad, desplegados desde codigo y gestionados desde Git, rotos a proposito cada mes para demostrar que se recuperan

**Descripcion**
Cluster k3s sobre Proxmox creado con Terraform y gobernado por ArgoCD, donde nada se despliega a mano porque si no esta en Git no existe. Corre una aplicacion con autoescalado y una PostgreSQL con failover automatico entre nodos. Lo importante no es el despliegue sino los cuatro simulacros cronometrados que lo acompanan. Al matar un nodo en caliente se pierde una sola peticion de 4315, PostgreSQL promociona su replica sin que nadie se lo pida y los pods se recolocan solos. Un despliegue roto un viernes produce cero segundos de corte en 3437 sondeos, porque la sonda de readiness congela el rollout y las replicas viejas siguen sirviendo: el arreglo es un revert de Git. Un pico de 3081 peticiones por segundo dobla las replicas de 3 a 6 en 40 segundos con la latencia plana y sin un solo fallo en 924512 peticiones. Y la prueba final destruye los tres nodos con el cluster vivo y lo reconstruye entero, certificados y datos incluidos, en 9 minutos y 37 segundos desde Git y una copia de 4 KB.

**Tecnologias**
k3s, Proxmox, Terraform, ArgoCD, CloudNativePG, MetalLB, cert-manager, Prometheus, Grafana, k6

**Enlace**
github.com/yosefnaabid/k3s-ha-chaos-lab
