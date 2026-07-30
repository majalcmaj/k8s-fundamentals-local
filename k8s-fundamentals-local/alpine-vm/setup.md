# Setup

Do these steps to ensure the created machines are configurable with ansible.

### Install Python 3

Needed by non-trivial ansible modules.

```apk add python3```

### Enable ssh root login

1. Edit `/etc/ssh/sshd_config`
2. Uncomment and provide value `PermitRootLogin yes`
3. Restart the sshd daemon: `service sshd restart`

### Copy your ssh keys

So ansible can act without the need for logging-in.
`ssh-copy-id root@<ip-address>` 
