# ЛР2. Керування БпЛА з ROS через MAVLink: ArduCopter SITL, MAVROS, Mission Planner

Шилюк Анна. Ubuntu 20.04 + ROS Noetic (VMware, NAT), ArduPilot **Copter-4.6.3**, Mission Planner на Windows.

## Структура

| Шлях | Що це |
|---|---|
| `lab_shyliuk/src/mission_ap.cpp` | вузол `mission_ap` (Завдання 4) |
| `lab_shyliuk/config/mission_ap.yaml` | висота `h`, точки A–D, критерій прибуття |
| `lab_shyliuk/launch/mission_ap.launch` | запуск однією командою |
| `scripts/00_cleanup_check.sh` | прибирання ВМ і перевірка середовища |
| `scripts/01_install_ardupilot.sh` | п. 3.1, кроки 1–3: клон, залежності, збірка SITL |
| `scripts/02_install_mavros.sh` | п. 3.3: MAVROS + GeographicLib |
| `scripts/03_build_package.sh` | додає `mission_ap` у пакет `lab_shyliuk` і збирає workspace |
| `scripts/run_sitl.sh` | SITL + MAVProxy з виходом `--out=127.0.0.1:14551` |
| `scripts/run_mavros.sh` | `roslaunch mavros apm.launch fcu_url:=udp://127.0.0.1:14551@14555` |
| `scripts/task3_flight.sh` | Завдання 3: політ командами `rosservice`/`rostopic pub` |
| `results/` | CSV польоту `mission_ap` |

## Встановлення

```bash
cd ~ && git clone https://github.com/Annafgb/lab2-ardupilot-mavros.git && cd lab2-ardupilot-mavros/scripts
./00_cleanup_check.sh
# >>> знімок ВМ у VMware (VM -> Snapshot -> Take Snapshot) <<<
./01_install_ardupilot.sh      # 20-40 хв
./02_install_mavros.sh
./03_build_package.sh
```

## Запуск

| Термінал | Команда |
|---|---|
| 1 | `./run_sitl.sh -w` (перший раз), далі `./run_sitl.sh` |
| 2 | `./run_mavros.sh` |
| 3 | `rostopic echo /mavros/state` → `connected: True` |
| 4 | `roslaunch lab_shyliuk mission_ap.launch` |

Свої координати (КТ3): скопіювати `config/mission_ap.yaml`, змінити A–D і запустити
`roslaunch lab_shyliuk mission_ap.launch config:=$HOME/route.yaml`.

## Схема з'єднань

```
Windows: Mission Planner --TCP--> 192.168.218.128:5762  (SITL SERIAL1)
ВМ:      MAVProxy        --TCP--> 127.0.0.1:5760        (SITL SERIAL0)
         MAVProxy        --UDP--> 127.0.0.1:14551 --> MAVROS (слухає локальний порт 14555)
         MAVROS <-- топіки/сервіси ROS --> mission_ap
```

* **5760, 5762, 5763** це TCP-сервери, які відкриває сам SITL: послідовні порти SERIAL0–2 симульованого польотного контролера. До кожного підключається один клієнт. MAVProxy займає 5760, тому Mission Planner підключається до 5762 з Windows за IP ВМ у мережі NAT.
* **14551** це додатковий UDP-вихід MAVProxy (`--out`), бо у 4.6.3 за замовчуванням є лише 14550. MAVProxy також запитує в автопілота потоки даних (позицію, стан), без цього `local_position` не оновлюється.

## Як працює mission_ap

1. Підписується на `/mavros/state` і `/mavros/local_position/pose`, чекає `connected == true`.
2. Викликає `/mavros/set_mode` з `GUIDED` раз на 2 с, поки `state.mode != GUIDED`.
3. Викликає `/mavros/cmd/arming` раз на 1,5 с, поки не `armed`. Відмову PreArm виводить у лог.
4. Одразу викликає `/mavros/cmd/takeoff` з висотою `h` і чекає `z ≥ 0,95·h`. Якщо автопілот зняв arm до зльоту, повертається до кроку 3.
5. Для A→B→C→D→A публікує `PoseStamped` у `/mavros/setpoint_position/local` з частотою 20 Гц, доки відстань < 0,5 м не протримається 1 с (критерій з ЛР1).
6. `LAND`, чекає автоматичного disarm після посадки.
7. Підсумок: загальний час, час зльоту, час і довжина маршруту, час кожного відрізка. Увесь час пише CSV: `~/mission_ap_log.csv`.

**Що змінилося порівняно з ЛР1.** Ціль тепер отримує не планувальник EGO-Swarm з ідеальним регулятором, а автопілот, і з цього випливає кілька речей:
* Перед рухом треба пройти стани апарата: GUIDED, arm, takeoff. Автопілот може відмовити (PreArm), а якщо зліт не почався за ~10 с після arm, він сам зніме arm. Тому у вузлі є цикли повторів і перевірка `state`.
* Ціль треба публікувати безперервно (10–20 Гц), а не один раз.
* Рух обмежують швидкість і прискорення контурів автопілота (`WPNAV_SPEED`, `WPNAV_ACCEL`, `WPNAV_SPEED_UP/DN`), тому відрізки займають більше часу, ніж в EGO-Swarm.
* Позиція надходить з EKF автопілота з частотою кількох Гц, а не з ідеального одометра симулятора.

## Відповіді для захисту

**GUIDED, LOITER, AUTO.**
* GUIDED: апарат виконує цілі (позиція, швидкість), які в реальному часі надходять ззовні по MAVLink від GCS або бортового комп'ютера, наприклад через MAVROS або «Fly To Here». Без нових команд він зависає на останній цілі.
* LOITER: ручний режим з утриманням позиції за GPS. Пілот керує стіками, а коли їх відпускає, апарат стоїть на місці.
* AUTO: виконання місії (список waypoint-ів), завантаженої в автопілот заздалегідь. Автопілот проходить її сам, без зовнішніх команд під час польоту.

**Системи координат.** ROS (REP-103/105) використовує **ENU**: x – схід, y – північ, z – вгору, а в тілі апарата FLU. ArduPilot і MAVLink працюють у **NED**: x – північ, y – схід, z – вниз, а в тілі FRD. Між ними перетворює **MAVROS**: міняє x↔y місцями, змінює знак z і повертає кватерніон. Результат Завдання 3 (таблиця нижче): x = 20 у ROS означає політ на **схід**, y = 20 означає політ на **північ**, z – вгору. Початок локальної системи – точка ініціалізації EKF (місце зльоту).

**Перевірки перед arm (PreArm, `ARMING_CHECK`).** Автопілот перевіряє:
* стан EKF (позиція й курс сходяться) і GPS: фікс, кількість супутників, HDOP;
* калібрування й узгодженість IMU (акселерометри, гіроскопи), компас, барометр;
* RC: калібрування, канал газу в мінімумі, failsafe;
* батарею, геозону, правильність параметрів;
* для arm у GUIDED/AUTO: режим має дозволяти arm, а позиція має бути відома.

Поки EKF/GPS у SITL не ініціалізовані (перші 30–60 с), arm відхиляється з повідомленням `PreArm: ...`.

## Завдання 3: осі

| Ціль у `/mavros/setpoint_position/local` | Напрямок на карті Mission Planner |
|---|---|
| x: 20, y: 0 | (заповнюється після польоту) |
| x: 0, y: 20 | (заповнюється після польоту) |

## Результати mission_ap

(заповнюється після польоту, див. `results/`)
