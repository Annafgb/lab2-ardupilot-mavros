#!/bin/bash
# Додає вузол mission_ap у пакет lab_shyliuk робочого простору catkin і збирає його.
# Якщо пакет lab_shyliuk з ЛР1 уже є — вузол додається в нього (з залежністю mavros_msgs),
# інакше пакет створюється з цього репозиторію.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WS="${WS:-}"
if [ -z "$WS" ]; then
  for d in ~/catkin_ws ~/*/; do [ -f "$d/src/CMakeLists.txt" ] && { WS="${d%/}"; break; }; done
fi
[ -n "$WS" ] || { WS=~/catkin_ws; mkdir -p "$WS/src"; }
PKG="$WS/src/lab_shyliuk"
source /opt/ros/noetic/setup.bash
echo "Workspace: $WS"
if [ -d "$PKG" ] && [ ! -L "$PKG" ] && ! grep -q mission_ap "$PKG/CMakeLists.txt"; then
  echo "Знайдено пакет lab_shyliuk з ЛР1 — додаю вузол mission_ap"
  mkdir -p "$PKG/src" "$PKG/launch" "$PKG/config"
  cp "$REPO/lab_shyliuk/src/mission_ap.cpp" "$PKG/src/"
  cp "$REPO/lab_shyliuk/launch/mission_ap.launch" "$PKG/launch/"
  cp "$REPO/lab_shyliuk/config/mission_ap.yaml" "$PKG/config/"
  grep -q '<depend>mavros_msgs</depend>\|<build_depend>mavros_msgs' "$PKG/package.xml" || \
    sed -i 's#</package>#  <depend>mavros_msgs</depend>\n</package>#' "$PKG/package.xml"
  grep -q 'mavros_msgs' "$PKG/CMakeLists.txt" || \
    sed -i '0,/find_package(catkin REQUIRED COMPONENTS/s//find_package(catkin REQUIRED COMPONENTS mavros_msgs/' "$PKG/CMakeLists.txt"
  printf '\nadd_executable(mission_ap src/mission_ap.cpp)\ntarget_link_libraries(mission_ap ${catkin_LIBRARIES})\n' >> "$PKG/CMakeLists.txt"
elif [ ! -e "$PKG" ]; then
  ln -s "$REPO/lab_shyliuk" "$PKG"
fi
cd "$WS"
if [ -d .catkin_tools ]; then catkin build lab_shyliuk; else catkin_make; fi
grep -q "$WS/devel/setup.bash" ~/.bashrc || echo "source $WS/devel/setup.bash" >> ~/.bashrc
echo "=== Готово. Відкрийте новий термінал або: source $WS/devel/setup.bash ==="
