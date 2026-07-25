# Export/reuse the `alpine` domain's disk for `cp-node`

Copies the manually-installed Alpine disk (from the `alpine` libvirt domain,
session scope) onto the terraform-managed `cp-node` domain (system scope),
replacing its blank disk.

## Prerequisites

- `alpine` domain exists (`qemu:///session`), installed via
  `alpine-vm/install-script.sh`.
- `cp-node` domain exists (`qemu:///system`), managed by
  `terraform/terraform.tf`, disk source pointing at
  `terraform/alpine.qcow2`.

## Steps

1. **Check both domains' current state.**
   ```bash
   virsh list --all                       # session scope -> alpine
   virsh -c qemu:///system list --all      # system scope  -> cp-node
   ```

2. **Stop both domains.** Copying a qcow2 file while a running QEMU process
   has it open corrupts/races the write.
   ```bash
   virsh shutdown alpine                   # graceful ACPI shutdown
   virsh -c qemu:///system destroy cp-node # hard stop is fine, disk being replaced anyway
   ```
   Wait until `virsh list --all` shows `alpine` as `shut off`. If it never
   responds to ACPI shutdown (no acpid in guest), fall back to
   `virsh destroy alpine`.

3. **Copy the disk over.**
   ```bash
   cp --sparse=always -v \
     ~/.local/share/libvirt/images/alpine.qcow2 \
     /home/mc/workspace/k8s-training/k8s-fundamentals-local/terraform/alpine.qcow2
   ```
   Source path is wherever `install-script.sh`'s `--disk` landed
   (`virt-install` default: `~/.local/share/libvirt/images/<name>.qcow2`
   for session scope).

4. **Restart `alpine`.**
   ```bash
   virsh start alpine
   ```

5. **Make sure `terraform.tf`'s disk driver type is `qcow2`, not the
   default `raw`.** This is the part that actually matters — the file *is*
   qcow2; without an explicit driver type the provider defaults to `raw`,
   so QEMU reads the qcow2 header bytes as if they were the boot sector and
   the guest never gets past BIOS (looks identical to "disk has no OS on
   it" — 1 read of 512 bytes, then a permanent SeaBIOS halt loop).
   ```hcl
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
   ```

6. **Apply.**
   ```bash
   terraform apply
   ```
   This restarts `cp-node` with the copied disk (device changes force a
   stop/start, ~30s).

7. **Verify it actually booted**, before trusting the console:
   ```bash
   virsh -c qemu:///system domblkstat cp-node vda
   ```
   Look for `rd_req` in the thousands and `rd_bytes` tens of MB — a couple
   hundred bytes and `rd_req 1` means it only ever read the MBR and gave up
   (bad driver type, or genuinely no OS on the disk).

   ```bash
   virsh -c qemu:///system qemu-monitor-command cp-node --hmp "info registers" \
     | grep -E "^EIP|^RIP|^CS |HLT"
   ```
   `CS=f000` / `EIP` stuck at a fixed address = still in BIOS ROM, not
   booted. `CS=0010`, `CS64`, `RIP` in the `0xffffffff8...` range = kernel
   is running (that's the normal Linux kernel base for x86_64).

8. **Connect.**
   ```bash
   virsh -c qemu:///system console cp-node
   ```
   (`Ctrl+]` to exit.)

## Known-good baseline config notes

`cp-node`'s domain needs these to boot/console at all on q35 (independent
of the disk-copy steps above, but easy to lose if the resource gets
recreated from scratch):

- `features.acpi = true` — q35 without ACPI hangs mid-POST (CPU parks in a
  fixed `HLT` loop inside BIOS ROM, indistinguishable at a glance from the
  driver-type bug above; check `info registers` twice a couple seconds
  apart — if `EIP`/`RIP` doesn't move at all, it's ACPI, not disk).
- `devices.serials` (`isa-serial`, port 0) + `devices.consoles`
  (`target.type = "serial"`, port 0) — without these there's no console
  device at all and `virsh console` has nothing to attach to.
- No `<video>`/graphics device is defined, so BIOS boot-menu text is
  invisible (goes nowhere) — this is expected and not a bug. Only the
  guest OS's own serial output (kernel + getty on `ttyS0`) is visible over
  `virsh console`.
- Networking: `br0` currently has no host IP, no DHCP, no uplink — the
  bridge only contains the VM's own tap interface. Console is the only way
  in until that's addressed separately (see main convo / TODO: NAT via
  libvirt `default` network needs the `sch_htb` kernel module, currently
  unavailable because the running kernel is older than the installed
  kernel package — needs a reboot).
