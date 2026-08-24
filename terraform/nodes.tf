# Nodos del cluster como CONTENEDORES LXC, no como maquinas virtuales.
#
# Por que LXC y no VMs:
# Un contenedor comparte el kernel del anfitrion, asi que no hay una segunda
# capa de virtualizacion. En un laboratorio que ya corre sobre un hipervisor
# anidado, esa capa de mas es la diferencia entre un cluster que funciona y uno
# que se cae solo: con VMs, las escrituras de etcd tardaban entre 500 y 980 ms
# y el cluster entraba en un bucle de elecciones de lider (ver docs/lab-notes.md).
#
# k3s dentro de LXC necesita un contenedor privilegiado y algunos permisos que
# no son los de un contenedor normal. Todo eso esta declarado aqui abajo.

resource "proxmox_virtual_environment_container" "k3s_node" {
  for_each = var.nodes

  node_name = var.proxmox_node
  vm_id     = each.value.vmid
  tags      = ["k3s", "lab"]

  # k3s necesita montar cgroups, cargar modulos y escribir en sitios que un
  # contenedor sin privilegios no toca.
  unprivileged = false

  features {
    # nesting deja correr containerd dentro del contenedor
    nesting = true
    # keyctl lo pide containerd para el llavero del kernel
    keyctl = true
    fuse   = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 3072
    # k3s se niega a arrancar con swap activo
    swap = 0
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
  }

  # En LXC la interfaz de red hay que declararla, no se crea sola como en una VM
  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.dns_server]
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  start_on_boot = true
  started       = true

  # El proveedor no expone las claves lxc.* en crudo, y k3s las necesita.
  # Se aplican con scripts/prepare-lxc.sh justo despues de crear los nodos.
  lifecycle {
    ignore_changes = [started]
  }
}
