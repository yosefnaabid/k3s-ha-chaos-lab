# Tarjeta para yosefnaabid.com

Contenido listo para la tarjeta del portfolio, en el mismo tono que las demas. Las cifras entre corchetes se rellenan con los resultados reales de los simulacros antes de publicarla.

---

**Titulo**
Cluster Kubernetes que sobrevive a la muerte de un nodo

**Linea corta**
Tres nodos con etcd en alta disponibilidad, desplegados desde codigo y gestionados desde Git, rotos a proposito cada mes para demostrar que se recuperan

**Descripcion**
Cluster k3s sobre Proxmox creado con Terraform y Ansible y gobernado por ArgoCD, donde nada se despliega a mano porque si no esta en Git no existe. Corre una aplicacion con autoescalado y una PostgreSQL con failover automatico entre nodos. Lo importante no es el despliegue sino los cuatro simulacros cronometrados que lo acompanan. Al matar un nodo en caliente el servicio se degrada [X] segundos y se recompone solo. Un despliegue roto un viernes produce cero segundos de corte y se revierte con un revert de Git. Un pico de carga dobla las replicas de 3 a 6 con la latencia estable. Y la prueba final destruye las tres maquinas con el cluster vivo y lo reconstruye entero desde Git y las copias en [X] minutos.

**Tecnologias**
k3s, Proxmox, Terraform, Ansible, ArgoCD, CloudNativePG, MetalLB, cert-manager, Prometheus, Grafana, k6

**Enlace**
github.com/yosefnaabid/k3s-ha-chaos-lab
