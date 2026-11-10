// mission_ap — вузол ЛР2: політ ArduCopter SITL через MAVROS за маршрутом A->B->C->D->A.
// Логіка прибуття, запис CSV і підсумок перенесено з вузла mission ЛР1:
// точку вважаємо досягнутою, коли відстань < tol утримується не менше hold секунд.
#include <ros/ros.h>
#include <geometry_msgs/PoseStamped.h>
#include <mavros_msgs/State.h>
#include <mavros_msgs/SetMode.h>
#include <mavros_msgs/CommandBool.h>
#include <mavros_msgs/CommandTOL.h>
#include <clocale>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <string>
#include <vector>

namespace {

mavros_msgs::State g_state;
geometry_msgs::PoseStamped g_pose;
bool g_have_pose = false;
double g_path_len = 0.0;           // довжина пройденого шляху, м
bool g_count_path = false;         // рахувати шлях лише в польоті
geometry_msgs::Point g_prev;
bool g_have_prev = false;

void stateCb(const mavros_msgs::State::ConstPtr& m) { g_state = *m; }

void poseCb(const geometry_msgs::PoseStamped::ConstPtr& m) {
  g_pose = *m;
  g_have_pose = true;
  const auto& p = m->pose.position;
  if (g_count_path && g_have_prev) {
    g_path_len += std::sqrt(std::pow(p.x - g_prev.x, 2) + std::pow(p.y - g_prev.y, 2) +
                            std::pow(p.z - g_prev.z, 2));
  }
  g_prev = p;
  g_have_prev = true;
}

struct Wp { std::string name; double x, y, z; };

double dist(const geometry_msgs::Point& p, const Wp& w) {
  return std::sqrt(std::pow(p.x - w.x, 2) + std::pow(p.y - w.y, 2) + std::pow(p.z - w.z, 2));
}

}  // namespace

int main(int argc, char** argv) {
  std::setlocale(LC_ALL, "");  // інакше rosconsole виводить кирилицю як ????
  ros::init(argc, argv, "mission_ap");
  ros::NodeHandle nh, pnh("~");

  // ---- параметри ----
  double h, tol, hold, rate_hz;
  std::string csv_path;
  pnh.param("h", h, 10.0);              // висота польоту, м
  pnh.param("tol", tol, 0.5);           // радіус прибуття, м
  pnh.param("hold", hold, 1.0);         // час утримання в радіусі, с
  pnh.param("rate", rate_hz, 20.0);     // частота публікації цілі, Гц
  pnh.param<std::string>("csv", csv_path, "mission_ap_log.csv");

  std::vector<Wp> pts;
  for (const std::string n : {"A", "B", "C", "D"}) {
    std::vector<double> xy;
    if (!pnh.getParam(n, xy) || xy.size() < 2) {
      ROS_FATAL("Параметр ~%s має бути списком [x, y] (метри від точки зльоту)", n.c_str());
      return 1;
    }
    pts.push_back({n, xy[0], xy[1], h});
  }
  std::vector<Wp> route = {pts[0], pts[1], pts[2], pts[3], pts[0]};  // A B C D A

  ros::Subscriber s_state = nh.subscribe("/mavros/state", 10, stateCb);
  ros::Subscriber s_pose = nh.subscribe("/mavros/local_position/pose", 10, poseCb);
  ros::Publisher p_sp = nh.advertise<geometry_msgs::PoseStamped>("/mavros/setpoint_position/local", 10);
  ros::ServiceClient c_mode = nh.serviceClient<mavros_msgs::SetMode>("/mavros/set_mode");
  ros::ServiceClient c_arm = nh.serviceClient<mavros_msgs::CommandBool>("/mavros/cmd/arming");
  ros::ServiceClient c_tol = nh.serviceClient<mavros_msgs::CommandTOL>("/mavros/cmd/takeoff");

  ros::Rate rate(rate_hz);

  std::ofstream csv(csv_path);
  csv << "t,phase,target,tx,ty,tz,x,y,z,dist,mode,armed\n";
  const ros::Time t0 = ros::Time::now();
  auto log = [&](const std::string& phase, const Wp* w) {
    const auto& p = g_pose.pose.position;
    csv << std::fixed << std::setprecision(3) << (ros::Time::now() - t0).toSec() << ',' << phase << ','
        << (w ? w->name : "-") << ',' << (w ? w->x : 0) << ',' << (w ? w->y : 0) << ',' << (w ? w->z : 0) << ','
        << p.x << ',' << p.y << ',' << p.z << ',' << (w ? dist(p, *w) : 0) << ',' << g_state.mode << ','
        << int(g_state.armed) << '\n';
  };
  auto spin = [&](const std::string& phase, const Wp* w = nullptr) {
    ros::spinOnce();
    log(phase, w);
    rate.sleep();
  };

  // 1. чекаємо з'єднання з автопілотом і першої позиції
  ROS_INFO("Чекаю з'єднання MAVROS з автопілотом...");
  while (ros::ok() && (!g_state.connected || !g_have_pose)) spin("wait_fcu");
  ROS_INFO("FCU connected");

  // 2. режим GUIDED
  ros::Time last = ros::Time(0);
  while (ros::ok() && g_state.mode != "GUIDED") {
    if (ros::Time::now() - last > ros::Duration(2.0)) {
      mavros_msgs::SetMode sm;
      sm.request.custom_mode = "GUIDED";
      c_mode.call(sm);
      ROS_INFO("set_mode GUIDED -> mode_sent=%d", sm.response.mode_sent);
      last = ros::Time::now();
    }
    spin("set_guided");
  }
  ROS_INFO("Режим GUIDED");

  // 3-4. arm + takeoff; якщо автопілот зняв arm до зльоту — знову arm
  bool airborne = false;
  const ros::Time t_takeoff_start = ros::Time::now();
  while (ros::ok() && !airborne) {
    // arm: повторюємо раз на 1.5 с, поки не armed
    last = ros::Time(0);
    while (ros::ok() && !g_state.armed) {
      if (ros::Time::now() - last > ros::Duration(1.5)) {
        mavros_msgs::CommandBool a;
        a.request.value = true;
        bool ok = c_arm.call(a);
        ROS_WARN_COND(!(ok && a.response.success),
                      "Arm відхилено (result=%d) — автопілот ще не готовий (PreArm), повторюю...",
                      a.response.result);
        last = ros::Time::now();
      }
      spin("arming");
    }
    ROS_INFO("ARMED, зліт на %.1f м", h);

    mavros_msgs::CommandTOL to;
    to.request.altitude = h;
    to.request.latitude = to.request.longitude = to.request.min_pitch = to.request.yaw = 0;
    if (!c_tol.call(to) || !to.response.success) ROS_WARN("takeoff не прийнято (result=%d)", to.response.result);

    while (ros::ok() && g_state.armed) {
      if (g_pose.pose.position.z >= 0.95 * h) { airborne = true; break; }
      spin("takeoff");
    }
    if (!airborne) ROS_WARN("Автопілот зняв arm до зльоту — повторюю arm");
  }
  const double t_takeoff = (ros::Time::now() - t_takeoff_start).toSec();
  ROS_INFO("Висота %.2f м досягнута за %.1f с", g_pose.pose.position.z, t_takeoff);

  // 5. маршрут A -> B -> C -> D -> A
  g_count_path = true;
  g_path_len = 0.0;
  const ros::Time t_route = ros::Time::now();
  std::vector<double> seg_t;
  for (size_t i = 0; i < route.size() && ros::ok(); ++i) {
    const Wp& w = route[i];
    geometry_msgs::PoseStamped sp;
    sp.header.frame_id = "map";
    sp.pose.position.x = w.x;
    sp.pose.position.y = w.y;
    sp.pose.position.z = w.z;
    sp.pose.orientation.w = 1.0;
    ROS_INFO("Ціль %s (%.1f, %.1f, %.1f)", w.name.c_str(), w.x, w.y, w.z);
    const ros::Time ts = ros::Time::now();
    ros::Time inside_since(0);
    while (ros::ok()) {
      sp.header.stamp = ros::Time::now();
      p_sp.publish(sp);
      const double d = dist(g_pose.pose.position, w);
      if (d < tol) {
        if (inside_since.isZero()) inside_since = ros::Time::now();
        if (ros::Time::now() - inside_since >= ros::Duration(hold)) break;
      } else {
        inside_since = ros::Time(0);
      }
      spin("goto_" + w.name, &w);
    }
    seg_t.push_back((ros::Time::now() - ts).toSec());
    ROS_INFO("Точка %s досягнута за %.1f с", w.name.c_str(), seg_t.back());
  }
  const double t_route_total = (ros::Time::now() - t_route).toSec();
  g_count_path = false;
  const double route_len = g_path_len;

  // 6. посадка: LAND і чекаємо автоматичного disarm
  last = ros::Time(0);
  while (ros::ok() && g_state.mode != "LAND") {
    if (ros::Time::now() - last > ros::Duration(2.0)) {
      mavros_msgs::SetMode sm;
      sm.request.custom_mode = "LAND";
      c_mode.call(sm);
      last = ros::Time::now();
    }
    spin("set_land");
  }
  ROS_INFO("LAND, чекаю посадки й disarm...");
  while (ros::ok() && g_state.armed) spin("landing");
  csv.close();

  // 7. підсумок
  const double total = (ros::Time::now() - t0).toSec();
  ROS_INFO("========== ПІДСУМОК ==========");
  ROS_INFO("Загальний час (від запуску вузла до disarm): %.1f с", total);
  ROS_INFO("Зліт до %.0f м: %.1f с", h, t_takeoff);
  ROS_INFO("Маршрут A-B-C-D-A: %.1f с, довжина шляху %.1f м", t_route_total, route_len);
  for (size_t i = 0; i < seg_t.size(); ++i) {
    const std::string from = (i == 0) ? "зліт" : route[i - 1].name;
    ROS_INFO("  %s -> %s: %.1f с", from.c_str(), route[i].name.c_str(), seg_t[i]);
  }
  ROS_INFO("CSV: %s", csv_path.c_str());
  return 0;
}
