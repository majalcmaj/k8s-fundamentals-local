## Enable connecting to qemu by libvirt

`sudo systemctl start libvirtd-tcp.socket`

## Connecting to the virtual machine console:

`virsh -c qemu:///system console cp-node`

## Manage image snapshots

`qemu-img snapshot -l alpine.qcow2`
