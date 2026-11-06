#!/bin/bash
# Після збільшення диска у VMware: розширити розділ і файлову систему / на весь диск.
set -e
sudo apt-get install -y cloud-guest-utils >/dev/null
lsblk /dev/sda
ROOT=$(findmnt -no SOURCE /)          # напр. /dev/sda5 (логічний усередині розширеного /dev/sda2)
NUM=${ROOT##*sda}
if sudo parted -s /dev/sda print | awk '$1=="2"' | grep -q extended; then sudo growpart /dev/sda 2 || true; fi
sudo growpart /dev/sda "$NUM" || true
sudo resize2fs "$ROOT"
df -h /
