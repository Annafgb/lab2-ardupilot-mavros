#!/bin/bash
# Завдання 3: політ командами rosservice / rostopic (кожна команда виводиться перед виконанням).
# Запуск: ./task3_flight.sh    (SITL, Mission Planner, MAVROS уже працюють)
source /opt/ros/noetic/setup.bash
run() { echo; echo "\$ $*"; "$@"; }
pub() { # ціль у локальній системі; публікуємо 10 Гц $3 секунд
  echo; echo "\$ rostopic pub -r 10 /mavros/setpoint_position/local geometry_msgs/PoseStamped \"{header: {frame_id: 'map'}, pose: {position: {x: $1, y: $2, z: 10}, orientation: {w: 1}}}\""
  timeout "$3" rostopic pub -r 10 /mavros/setpoint_position/local geometry_msgs/PoseStamped \
    "{header: {frame_id: 'map'}, pose: {position: {x: $1, y: $2, z: 10}, orientation: {w: 1}}}"
}
run rosservice call /mavros/set_mode "{custom_mode: 'GUIDED'}"
sleep 2
run rosservice call /mavros/cmd/arming "{value: true}"
run rosservice call /mavros/cmd/takeoff "{altitude: 10}"
echo "... набір висоти"; sleep 15
pub 20 0 25
pub 0 20 30
run rosservice call /mavros/set_mode "{custom_mode: 'LAND'}"
