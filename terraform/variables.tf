variable "proxmox_endpoint" {
  description = "URL de la API de Proxmox, por ejemplo https://10.0.10.2:8006/"
  type        = string
}

variable "proxmox_username" {
  description = "Usuario de Proxmox. Tiene que ser root@pam para crear contenedores privilegiados"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Contrasena de root@pam. Nunca se commitea, va en terraform.tfvars"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "true si el certificado de Proxmox es autofirmado"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Nombre del nodo Proxmox donde se crean las VMs"
  type        = string
}

variable "lxc_template" {
  description = "Plantilla LXC de Debian 12 en Proxmox. Descargala con: pveam download local debian-12-standard_12.12-1_amd64.tar.zst"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}

variable "gateway" {
  description = "Puerta de enlace de la VLAN del laboratorio"
  type        = string
}

variable "dns_server" {
  description = "Servidor DNS para los nodos"
  type        = string
}

variable "ssh_public_key" {
  description = "Clave publica SSH que cloud-init inyecta en los nodos"
  type        = string
}

variable "vm_user" {
  description = "Usuario de acceso a los nodos. En LXC se entra como root"
  type        = string
  default     = "root"
}

# Tres nodos server de k3s. Las IPs deben estar FUERA del rango DHCP.
variable "nodes" {
  description = "Mapa de nodos del cluster con su vmid e IP en formato CIDR"
  type = map(object({
    vmid = number
    ip   = string
  }))
  default = {
    "k3s-1" = { vmid = 201, ip = "10.0.10.11/24" }
    "k3s-2" = { vmid = 202, ip = "10.0.10.12/24" }
    "k3s-3" = { vmid = 203, ip = "10.0.10.13/24" }
  }
}
