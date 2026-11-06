#!/bin/bash
# п. 3.3, крок 2: MAVROS для ArduPilot
source /opt/ros/noetic/setup.bash
roslaunch mavros apm.launch fcu_url:=udp://127.0.0.1:14551@14555
