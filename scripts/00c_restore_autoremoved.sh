#!/bin/bash
# Повертає пакети, які видалив "apt autoremove --purge" зі скрипта 00_cleanup_check.sh
# (серед них залежності EGO-Swarm: roslint, cmake_modules тощо). Список береться з журналу apt.
set -e
LOG=/var/log/apt/history.log
PKGS=$(awk '/^Commandline: apt-get -y autoremove --purge/{f=1;next} /^End-Date/{f=0} f && /^(Purge|Remove):/' "$LOG" \
  | sed -E 's/^(Purge|Remove): //; s/\([^)]*\)//g' | tr ',' '\n' | sed -E 's/:[a-z0-9]+ *$//; s/ //g' | grep -v '^$' | sort -u)
echo "Буде повернуто $(echo "$PKGS" | wc -l) пакетів:"; echo $PKGS
sudo apt-get update
sudo apt-get install -y $PKGS ros-noetic-roslint ros-noetic-cmake-modules
