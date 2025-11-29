#!/bin/bash
set -e

sudo apt update && sudo apt install -y isc-dhcp-server bind9 apache2 vsftpd nfs-kernel-server

sudo systemctl restart isc-dhcp-server bind9 apache2 vsftpd nfs-kernel-server
