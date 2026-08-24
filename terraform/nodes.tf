resource "proxmox_virtual_environment_vm" "k3s_node" {
  for_each = var.nodes

  name      = each.key
  vm_id     = each.value.vmid
  node_name = var.proxmox_node
  tags      = ["k3s", "lab"]

  clone {
    vm_id = var.template_vmid
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    size         = 40
  }

  initialization {
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
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }

  operating_system {
    type = "l26"
  }

  started = true
  on_boot = true
}
