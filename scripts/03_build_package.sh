#!/bin/bash
# Додає вузол mission_ap у пакет lab_shilyuk робочого простору catkin і збирає його.
# Якщо пакет lab_shilyuk з ЛР1 уже є — вузол додається в нього (з залежністю mavros_msgs),
# інакше пакет створюється з цього репозиторію.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WS="${WS:-}"
if [ -z "$WS" ]; then
  # спершу шукаємо робочий простір, де вже є пакет lab_shilyuk з ЛР1 (у мене ~/ego-planner-swarm)
  for d in ~/*/; do [ -d "$d/src/lab_shilyuk" ] && [ ! -L "$d/src/lab_shilyuk" ] && { WS="${d%/}"; break; }; done
fi
if [ -z "$WS" ]; then
  for d in ~/catkin_ws ~/*/; do [ -f "$d/src/CMakeLists.txt" ] && { WS="${d%/}"; break; }; done
fi
[ -n "$WS" ] || { WS=~/catkin_ws; mkdir -p "$WS/src"; }
PKG="$WS/src/lab_shilyuk"
source /opt/ros/noetic/setup.bash
echo "Workspace: $WS"
if [ -d "$PKG" ] && [ ! -L "$PKG" ] && ! grep -q mission_ap "$PKG/CMakeLists.txt"; then
  echo "Знайдено пакет lab_shilyuk з ЛР1 — додаю вузол mission_ap"
  mkdir -p "$PKG/src" "$PKG/launch" "$PKG/config"
  cp "$REPO/lab_shilyuk/src/mission_ap.cpp" "$PKG/src/"
  cp "$REPO/lab_shilyuk/launch/mission_ap.launch" "$PKG/launch/"
  cp "$REPO/lab_shilyuk/config/mission_ap.yaml" "$PKG/config/"
  grep -q '<depend>mavros_msgs</depend>\|<build_depend>mavros_msgs' "$PKG/package.xml" || \
    sed -i 's#</package>#  <depend>mavros_msgs</depend>\n</package>#' "$PKG/package.xml"
  grep -q '<depend>geometry_msgs</depend>\|<build_depend>geometry_msgs' "$PKG/package.xml" || \
    sed -i 's#</package>#  <depend>geometry_msgs</depend>\n</package>#' "$PKG/package.xml"
  cp "$PKG/CMakeLists.txt" "$PKG/CMakeLists.txt.bak_lab1"
  grep -q 'mavros_msgs' "$PKG/CMakeLists.txt" || \
    sed -i '0,/find_package(catkin REQUIRED COMPONENTS/s//find_package(catkin REQUIRED COMPONENTS mavros_msgs geometry_msgs/' "$PKG/CMakeLists.txt"
  grep -q 'include_directories' "$PKG/CMakeLists.txt" || echo 'include_directories(${catkin_INCLUDE_DIRS})' >> "$PKG/CMakeLists.txt"
  printf '\nadd_executable(mission_ap src/mission_ap.cpp)\ntarget_link_libraries(mission_ap ${catkin_LIBRARIES})\n' >> "$PKG/CMakeLists.txt"
elif [ ! -e "$PKG" ]; then
  ln -s "$REPO/lab_shilyuk" "$PKG"
fi
cd "$WS"
if [ -d .catkin_tools ]; then catkin build lab_shilyuk
else catkin_make --only-pkg-with-deps lab_shilyuk && (cd build && cmake . -DCATKIN_WHITELIST_PACKAGES="" >/dev/null); fi
grep -q "$WS/devel/setup.bash" ~/.bashrc || echo "source $WS/devel/setup.bash" >> ~/.bashrc
echo "=== Готово. Відкрийте новий термінал або: source $WS/devel/setup.bash ==="
