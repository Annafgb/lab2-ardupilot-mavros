#!/bin/bash
# п. 3.3, крок 1: MAVROS і набори даних GeographicLib
set -e
sudo apt-get update
sudo apt-get install -y ros-noetic-mavros ros-noetic-mavros-extras ros-noetic-roslint
cd ~
wget -q https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh -O install_geographiclib_datasets.sh
sudo bash ./install_geographiclib_datasets.sh
echo "=== MAVROS встановлено ==="
