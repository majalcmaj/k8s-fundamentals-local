#!/bin/bash
ip link add name br0 type bridge
ip link set dev br0 up
