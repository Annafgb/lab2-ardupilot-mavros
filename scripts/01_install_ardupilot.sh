#!/bin/bash
# п. 3.1, кроки 1-3: клонування ArduPilot Copter-4.6.3, залежності, збірка SITL
set -e
cd ~
[ -d ardupilot ] || git clone --recurse-submodules -b Copter-4.6.3 https://github.com/ArduPilot/ardupilot.git
cd ~/ardupilot
git submodule update --init --recursive
Tools/environment_install/install-prereqs-ubuntu.sh -y
. ~/.profile
./waf configure --board sitl
./waf copter
echo "=== ArduCopter SITL зібрано ==="; ls -la build/sitl/bin/arducopter
