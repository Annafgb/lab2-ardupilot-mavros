cmake_minimum_required(VERSION 3.0.2)
project(lab_shilyuk)
add_compile_options(-std=c++14)
find_package(catkin REQUIRED COMPONENTS roscpp geometry_msgs mavros_msgs)
catkin_package()
include_directories(${catkin_INCLUDE_DIRS})

add_executable(mission_ap src/mission_ap.cpp)
target_link_libraries(mission_ap ${catkin_LIBRARIES})
