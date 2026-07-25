#!/bin/bash

virt-install  \
  --name alpine \
  --memory 1024             \
  --vcpus=2,maxvcpus=4      \
  --cpu host-model                \
  --cdrom $HOME/Downloads/alpine.iso \
  --osinfo detect=on,name=alpinelinux3.23 \
  --disk size=10,format=qcow2  \
  --network user            \
  --virt-type kvm
