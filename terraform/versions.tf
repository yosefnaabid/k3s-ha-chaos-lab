terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60.0, < 1.0.0"
    }
  }
}

# Autenticacion con usuario y contrasena, no con token de API.
#
# Proxmox solo deja crear contenedores PRIVILEGIADOS con feature flags a
# root@pam autenticado de verdad. Un token de API, aunque sea de root@pam,
# recibe un 403: "changing feature flags for privileged container is only
# allowed for root@pam". Como los nodos de k3s tienen que ser privilegiados,
# aqui no queda otra que usuario y contrasena.
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_insecure

  ssh {
    agent    = false
    username = "root"
  }
}
