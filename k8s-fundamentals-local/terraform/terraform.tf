terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.8"
    }
  }

  required_version = ">= 1.13"
}

provider "libvirt" {
}

resource "libvirt_domain" "cp-node" {
  name        = "cp-node"
  type        = "kvm"
  memory      = 4
  memory_unit = "GiB"
  vcpu        = 2

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      { dev = "hd" },
      { dev = "network" }
    ]
  }

  features = {
    acpi = true
  }

  devices = {
    disks = [
      {
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          file = {
            file = "${path.cwd}/alpine.qcow2"
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      }
    ]
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
      }
    ]
    serials = [
      {
        target = {
          type = "isa-serial"
          port = 0
        }
      }
    ]
    consoles = [
      {
        target = {
          type = "serial"
          port = 0
        }
      }
    ]
  }
  running = true
}
