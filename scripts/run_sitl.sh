#!/bin/bash
# п. 3.1, крок 4: SITL ArduCopter + MAVProxy, вихід UDP 14551 для MAVROS.
# Перший запуск: ./run_sitl.sh -w   (скидання параметрів)
cd ~/ardupilot
. ~/.profile
sim_vehicle.py -v ArduCopter "$@" --custom-location=50.4501,30.5234,120,0 --out=127.0.0.1:14551
