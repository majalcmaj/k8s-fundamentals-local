# Road to Production

Gaps between this learning setup and a production-grade recipe. Terraform +
Ansible focus.

## Terraform

**State**
- State local, untracked (`.gitignore` covers it) — good. No locking, no
  remote backend. Prod: S3+DynamoDB, Terraform Cloud, or local backend w/
  locking for team safety.
- `.terraform.lock.hcl` gitignored — backwards. Lock file should be
  **committed** for reproducible provider versions across machines/CI.

**Structure**
- Single flat `terraform.tf`, no `variables.tf`/`outputs.tf`/modules.
  Memory, vcpu, node count all hardcoded. Fine for 1 VM; blocks scaling to
  multi-node cluster (control-plane + N workers) without copy-paste.
- One monolithic `libvirt_domain` resource, no `for_each`/`count`. Add a
  `workers` variable + `for_each` when more than one node is needed.
- Provider block empty (relies on env/system libvirt) — fine locally, but
  no documented connection URI (`qemu:///system` implicit). Worth pinning
  explicitly for clarity.

**Image provisioning**
- Disk (`alpine.qcow2`) built by hand (`install-script.sh` + manual
  `ssh-copy-id`, root-login enable, python3 install) then physically
  copied into `terraform/` per `export-disk-recipe.md`. Manual, not
  reproducible, not source-controlled (image itself gitignored, rightly).
- Prod path: bake image w/ **Packer** (or cloud-init) so image build is
  code, not a runbook. At minimum, use `libvirt_cloudinit_disk` to inject
  ssh key + enable root/python3 automatically instead of manual steps —
  kills the whole `setup.md` manual dance.

## Ansible

**Inventory / auth**
- Static IP hardcoded in `inventory.ini`, `ansible_user=root` w/ implicit
  ssh-agent auth. Prod: dedicated non-root user w/ `become: true`,
  explicit `ansible_ssh_private_key_file`, and inventory generated
  dynamically (or at minimum templated, not IP hardcoded per rebuild).
- Root SSH login enabled by design (`setup.md`) — acceptable for lab,
  security smell beyond it. Revisit before "production."

**Idempotency**
- `uuidgen > /etc/machine-id` runs unconditionally every play —
  regenerates machine-id on every run, breaking DHCP lease stability /
  node identity across reruns. Guard w/ `creates:` or a
  `when:` check against the existing file.
- Big `ansible.builtin.shell` block mixes package installs + service
  enable/start. Prefer `ansible.builtin.service`
  (`state=started`, `enabled=true`) and `community.general.apk` w/
  version pin instead of raw shell — proper change-tracking +
  idempotency instead of "always runs."
- `apk add 'kubelet=~1.36'` etc. inside shell duplicates the earlier
  `apk` module install task — consolidate, pin versions in the module
  task itself (`community.general.apk: name=kubelet=~1.36 state=present`).

**Structure**
- Single flat playbook, no roles, no tags, no handlers. Fine at this
  size; will hurt once kubeadm init/join, worker join, HA etcd, cert
  distribution etc. get added. Split into roles (`common`,
  `control_plane`, `worker`) before it grows more.
- `alpine_version` hardcoded var in playbook, not `group_vars`. Move to
  `group_vars/all.yml` so it's overridable per-environment.
- No `ansible.cfg` (host key checking, retry files, roles_path
  undefined).
- No `ansible-lint` / molecule testing.

## Priority order

1. Commit `.terraform.lock.hcl`; add remote state backend + locking.
2. Replace manual VM bootstrap (`setup.md` + disk-copy dance) with
   cloud-init image build (Packer or `libvirt_cloudinit_disk`) — biggest
   reproducibility win.
3. Fix machine-id idempotency bug in Ansible.
4. Parameterize both Terraform (vars/modules for node count) and Ansible
   (`group_vars`, roles) so multi-node (control-plane + workers) is a
   config change, not new code.
5. Move off root SSH login to dedicated user + `become`; consider
   `ansible-vault`/SOPS once real secrets appear.
6. Split ansible into roles now, before the playbook grows past the next
   round of additions.
