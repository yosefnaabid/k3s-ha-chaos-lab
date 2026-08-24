# El unico secreto del proyecto

Todo el repositorio es publico y reproducible menos una cosa, el token de Cloudflare que usa cert-manager para el reto DNS. Se crea una vez, a mano, despues de instalar cert-manager y antes de que ArgoCD sincronice el ClusterIssuer.

## Crear el token

En el panel de Cloudflare crea un API Token con la plantilla Edit zone DNS limitado a la zona yosefnaabid.com. No uses la Global API Key.

## Meterlo en el cluster

```bash
kubectl -n cert-manager create secret generic cloudflare-api-token \
  --from-literal=api-token=PEGA_AQUI_TU_TOKEN
```

## Por que no esta en Git

Un secreto en un repo publico deja de ser un secreto en el minuto uno, los bots escanean GitHub en tiempo real. La alternativa para tener el repo cien por cien autosuficiente seria sealed-secrets, que cifra el secreto con la clave publica del cluster y permite commitear el resultado. Queda anotada como mejora, para el laboratorio un secreto manual documentado es el equilibrio correcto entre pureza GitOps y simplicidad.

## El resto de credenciales

La clave de Grafana viene de los values y se cambia en el primer login. La contraseña de PostgreSQL la genera el operador CloudNativePG solo y vive en el secreto pg-lab-app dentro del cluster. El token de la API de Proxmox y el de k3s van en ficheros que el .gitignore excluye, con sus plantillas .example versionadas.
