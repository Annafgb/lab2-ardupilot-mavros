#!/bin/bash
# п. 3.1, кроки 1-3: клонування ArduPilot Copter-4.6.3, залежності, збірка SITL
set -e
cd ~
[ -d ardupilot ] || git clone --recurse-submodules -b Copter-4.6.3 https://github.com/ArduPilot/ardupilot.git
cd ~/ardupilot
# якщо репозиторій уже був склонований раніше - переходимо на зафіксовану версію Copter-4.6.3
if [ "$(git describe --tags --exact-match 2>/dev/null)" != "Copter-4.6.3" ]; then
  git fetch origin tag Copter-4.6.3 --no-tags || git fetch origin --tags
  git checkout -f Copter-4.6.3
fi
git submodule sync --recursive
git submodule update --init --recursive
echo "ArduPilot: $(git describe --tags)"
Tools/environment_install/install-prereqs-ubuntu.sh -y
. ~/.profile
./waf configure --board sitl
./waf copter
echo "=== ArduCopter SITL зібрано ==="; ls -la build/sitl/bin/arducopter
