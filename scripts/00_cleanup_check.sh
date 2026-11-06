#!/bin/bash
# Прибирання зайвого у ВМ і перевірка середовища перед ЛР2
echo "=== До прибирання ==="; df -h / | tail -1
pkill -f '/ttyd' 2>/dev/null; rm -f ~/ttyd ~/.vmagent.py ~/.vmagent.log /tmp/ag.b64
sudo apt-get -y clean
sudo journalctl --vacuum-size=50M >/dev/null 2>&1
rm -rf ~/.cache/* ~/.local/share/Trash/* 2>/dev/null
rm -rf ~/.ros/log/* 2>/dev/null
echo "=== Після прибирання ==="; df -h / | tail -1
echo "=== Середовище ==="
lsb_release -ds; echo "ROS: $(ls /opt/ros 2>/dev/null)"; nproc; free -h | sed -n 2p
echo "=== Робочі простори catkin і пакети ==="
for d in ~/*/; do [ -f "$d/src/CMakeLists.txt" ] && { echo "WS: $d"; ls "$d/src"; }; done
find ~ -maxdepth 4 -name package.xml -path '*lab_*' 2>/dev/null
echo "=== Великі теки в домашній ==="; du -sh ~/* 2>/dev/null | sort -h | tail -8
