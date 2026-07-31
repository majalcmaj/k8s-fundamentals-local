packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "ssh_username" {
  type = string
  default = "user"
}

variable "root_password" {
  type = string
  default = "root"
}

source "qemu" "alpine" {
  iso_url           = "https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86/alpine-virt-3.24.1-x86.iso"
  iso_checksum      = "sha256:9895695d27eabc1e2782598ff0190f7966df8317cc2afe2a6d25360e148a4209"
  http_directory    = "http"
  output_directory  = "output_alpine"
  shutdown_command  = "/sbin/poweroff"
  disk_size         = "5000M"
  format            = "qcow2"
  accelerator       = "kvm"
  ssh_username      = "root"
  ssh_password      = "root"
  ssh_timeout       = "20m"
  vm_name           = "alpine"
  net_device        = "virtio-net"
  disk_interface    = "virtio"
  communicator      = "ssh"
  boot_wait         = "10s"
  boot_command      = [
        "root<enter><wait>",
        "ifconfig eth0 up && udhcpc -i eth0<enter><wait5>",
        "export ERASE_DISKS=/dev/sda<enter>",
        "export USEROPTS='-a -u -g audio,video,netdev ${var.ssh_username}'<enter>",
        "export USERSSHKEY='http://{{ .HTTPIP }}:{{ .HTTPPort}}/ssh.keys'<enter>",
        "wget http://{{ .HTTPIP }}:{{ .HTTPPort }}/answers<enter><wait>",
        "cat $PWD/answers<enter><wait5>",
        "setup-alpine -f $PWD/answers<enter><wait5>",
        "${var.root_password}<enter><wait>",
        "${var.root_password}<enter><wait30>",
        "mount /dev/sda3 /mnt<enter>",
        "echo 'PermitRootLogin yes' >> /mnt/etc/ssh/sshd_config<enter>",
        "umount /mnt; reboot<enter>"
    ] 
}

build {
  sources = ["source.qemu.alpine"]
}

