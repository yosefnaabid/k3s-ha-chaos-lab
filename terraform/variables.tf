variable "proxmox_endpoint" {
  description = "URL de la API de Proxmox, por ejemplo https://10.0.10.2:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Token de API con formato usuario@pve!nombre=uuid. Nunca se commitea, va en terraform.tfvars"
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

variable "template_vmid" {
  description = "VMID de la plantilla cloud-init de Debian 12 (paso 0.1 del plan)"
  type        = number
  default     = 9000
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
  description = "Usuario que crea cloud-init en los nodos"
  type        = string
  default     = "admin"
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
