# RTS "база на базу": план реализации

## Контекст

Сейчас в проекте есть глубокий, но чисто одиночный движок тела/боя/мира: `PlayerBody` (12 видов оружия, стамина, навыки, смерть/добивание, ношение предметов), `Knight` (ИИ на том же теле), процедурная анимация `Gait`/`walker.gd`, цепочка ресурсов дерево→брёвна→костёр и руда→камень, и три вида животных. UI, сохранений, pathfinding'а, фракций и сети в проекте нет вообще — это подтверждено сканированием (`project.godot` без `[autoload]`/`[input]`, ни одного `extends Control`, ни одного `FileAccess`/`ConfigFile`, ни одного `NavigationAgent2D`).

Цель — превратить это в RTS «база на базу»: добыча дерева/руды/золота, найм юнитов, сбор в толпу или отправка в атаку, ИИ-противник с зеркальной экономикой, разрушаемая база и башни, карта, меню, ачивки. Камера/мир остаются топ-даун свободным перемещением (как сейчас), не боковой лейн — решено пользователем. Сеть сейчас **не реализуется**, но архитектура должна закладываться так, чтобы её можно было добавить позже без переписывания ядра — тоже явное решение пользователя.

Ключевой принцип, который уже используется в коде и на который опирается весь план: **интерфейс — это членство в группе + duck-typing методов, а не наследование**. `TargetDummy` — доказательство: он не наследует `PlayerBody`, но полноценно участвует в бою через `is_alive()/take_hit()/exposed_back_to()`. Новые сущности (База, Башня) следуют этому же контракту, не наследуя тяжёлый `PlayerBody`.

**Существующий тестовый стенд (`scenes/main/Main.tscn` + `debug_panel.gd`) не трогаем вообще** — вся RTS-часть строится в новых файлах/сценах. Это гарантирует, что процедурная анимация и боевой rig не сломаются по пути.

---

## Архитектура

### 1. Фракции — минимальное вмешательство

Урон и попадания (`PlayerBody._nearest_target`, `hit_target_at`, `land_strike`) остаются **полностью team-agnostic**, как сейчас — это чисто механика "могу ли я сейчас попасть", она не должна знать про фракции. Команда нужна только на уровне ИИ-решения "в кого целиться боевым намерением" (`Unit._who_to_watch`).

Новый файл `scripts/team.gd`:
```gdscript
class_name Team
enum Id { NEUTRAL, PLAYER, ENEMY }
static func hostile(a: int, b: int) -> bool:
    return a != Id.NEUTRAL and b != Id.NEUTRAL and a != b
```
В `player.gd` добавляется `@export var team: int = Team.Id.NEUTRAL` и `func team_of() -> int: return team`. `TargetDummy` не получает `team_of()` вовсе (или NEUTRAL) — это воспроизводит нынешнее поведение "рыцарь не трогает чучело" бесплатно.

В `_who_to_watch()` (после переименования Knight→Unit, см. п.2) строка `candidate is Knight: continue` заменяется на проверку `Team.hostile(team, candidate.team_of())`. Это единственная точка, которая меняется под фракции.

### 2. Юниты и команды — расширение, не переписывание FSM

`scripts/knight.gd` → `scripts/unit.gd`, `class_name Knight` → `class_name Unit` (переставить путь скрипта в `Knight.tscn`). Существующий `Watch { PATROL, NOTICED, FIGHTING, RETURNING }` не трогаем.

Инсайт: `post` уже означает "точка сбора", `PATROL` уже ходит вокруг неё, `RETURNING` уже идёт туда же — это уже семантика rally point. Добавляем:
```gdscript
enum Order { HOLD, ATTACK_MOVE }
var order := Order.HOLD
var attack_goal := Vector2.ZERO
func set_rally(point: Vector2) -> void:
    order = Order.HOLD; post = point
func set_attack_move(goal: Vector2) -> void:
    order = Order.ATTACK_MOVE; attack_goal = goal
```
`set_rally` не требует изменений внутри `match watch:` вообще. `ATTACK_MOVE` требует ~4 строки внутри `PATROL`/`RETURNING`: если `order == ATTACK_MOVE` и `quarry == null` — идти к `attack_goal` вместо патруля/возврата к посту. `FIGHTING`/`NOTICED` не трогаем.

Групповая команда — `scripts/squad.gd` (`class_name Squad extends Node`, массив `Unit`, методы `rally(point)`/`attack_move(point)`), лежит на стороне `PlayerState` (п.6). Это весь словарь команд игрока — важно для п.11 (сеть).

### 3. Рабочие (экономический ИИ)

`scripts/worker.gd`, `class_name Worker extends PlayerBody` — тот же паттерн, что `Unit`: движение через `_get_input_vector()`, а реальные действия — уже готовые публичные методы `PlayerBody`: `chop_tree()`, `strike_vein()`, `pick_up()`, `put_down_rock()`, `nearest_tree()`, `nearest_vein()` (все уже без `_`, публичны — проверено). Состояния: `TO_RESOURCE / GATHERING / TO_STOCKPILE / DEPOSITING / IDLE`.

Резервирование ресурса между несколькими рабочими — добавить `reserved_by`/`reserve()`/`release()` в `tree.gd`/`ore_vein.gd` (~6 строк каждый); можно отложить до M4, при малом числе рабочих не критично.

`Worker` наследует `PlayerBody`, значит автоматически состоит в `"targets"` — вражеские `Unit` смогут убивать вражеских рабочих, это ожидаемое поведение RTS.

### 4. Pathfinding

Раз мир остаётся топ-даун свободным (не лейн), нужен настоящий 2D pathfinding — встроенный `NavigationRegion2D`/`NavigationAgent2D`, не самописный.

- Один статичный `NavigationRegion2D` на весь пол (900×560), запекается один раз при старте карты, не перезапекается.
- `NavigationObstacle2D` как дочерний узел у `ChopTree`, `OreVein`, сегментов `Walls`, у `Base`/`Tower`/`ProductionBuilding` — `NavigationServer2D` сам обходит их без перезапекания; спиленное дерево просто убирает свой `NavigationObstacle2D`.
- `NavigationAgent2D` — дочерний узел в `Unit.tscn`/`Worker.tscn`.

> **Как сделано в M2 (отличие от плана выше):** в Godot 4 `NavigationObstacle2D` влияет только на avoidance, не на путь. Поэтому `NavFloor` (`scripts/nav_floor.gd`) запекает пол из уже существующих `StaticBody2D`: у деревьев, жил и стен они есть, у зданий будут. Запекание одно, при старте: препятствия только уменьшаются (дерево→пень), так что старая сетка лишь чуть осторожнее. Новое препятствие → `NavFloor.rebake()`. `NavigationAgent2D` создаётся в коде `Unit._ready()` с включённым RVO-avoidance. Без навигационного региона на карте (тестовый стенд) юнит ходит по-старому, только по X.

Точка интеграции — тот же `_get_input_vector()`, который уже использует `Knight`. Меняется только `_walk_towards()`:
```gdscript
func _walk_towards(there: Vector2, effort: float) -> bool:
    nav_agent.target_position = there
    if nav_agent.is_navigation_finished(): return true
    wish = (nav_agent.get_next_path_position() - global_position).normalized() * effort
    return false
```
`_physics_process`/`move_and_slide()` в `player.gd` не меняются вообще.

### 5. Здания

- **`Base`** (`scripts/base_building.gd`, `extends StaticBody2D`) — реализует контракт напрямую по образцу `TargetDummy` (без наследования `PlayerBody`): `is_alive()/take_hit()/exposed_back_to() -> false/team_of()`. Группы `"targets"` + новая `"bases"`. Сигнал `base_destroyed(team)` — хук для победы/ачивок.
- **`ProductionBuilding`** (`scripts/production_building.gd`) — `@export unit_scene/team/rally_marker`, метод `queue_unit(kind: String) -> bool` (списывает ресурсы через `Economy`), таймер найма, по готовности спавнит юнита и сразу `unit.set_rally(rally_point)`. Этот метод вызывается одинаково и из HUD, и из ИИ (п.10) — один код-путь на обе стороны.
- **`Stockpile`** (`scripts/stockpile.gd`) — копирует паттерн `Campfire._take_fuel()` (сканирование `"carriables"` в радиусе, тот же guard на `is_queued_for_deletion()`): свободные `Beam`→wood, `Rock`→ore/gold (по `resource_kind`), зачисление в `Economy`, `queue_free()`.
- **Золото** — не отдельная "пассивная" механика, а третий тип жилы: экспортируемое поле `resource_kind` в `OreVein` (или отдельный `GoldVein extends OreVein`), чтобы добыча золота шла тем же кодом, что и руда.
- **Важное уточнение по экономике (явно задано пользователем)**: `Economy.ore`/`Economy.gold` увеличиваются **только в момент сдачи на склад**, а не в момент удара киркой. Полная цепочка уже наполовину готова существующим `OreVein`/`Rock`: `Worker` подходит к жиле → бьёт киркой (`strike_vein()`, существующий метод `OreVein.take_strike()` откалывает кусок и выбрасывает `Rock` — без изменений) → `Worker` поднимает выпавший `Rock` (`pick_up()`) → несёт к `Stockpile` → только там `Stockpile` списывает `Rock` (`queue_free()`) и вызывает `Economy.add(resource_kind, amount)`. До этого момента добытый кусок — это просто физический объект `Rock`, лежащий или переносимый в мире, а не число в экономике. Дерево работает по той же схеме через `Beam` (уже так и есть в `Campfire`). Это поведение одинаково и для рабочего игрока, и для рабочего ИИ (`Worker` — общий класс для обеих сторон, см. п.3) — никакого отдельного "мгновенного" начисления для ИИ не делаем, чтобы не расходовать поведение и баланс.
- **`Tower`** — **отдельный лёгкий класс**, не `PlayerBody` (снаряды `Arrow`/`Chip`/`Bolt` в `walker.gd` — приватные вложенные классы, завязанные на конкретное тело, для безногой башни не подходят). `extends StaticBody2D`, свой контракт `is_alive/take_hit/exposed_back_to=false/team_of`, свой throttled-скан ближайшей вражеской цели и прямой вызов `mark.take_hit(...)`. Визуал снаряда, если понадобится — по паттерну `Campfire.Mote` (маленький локальный класс + массив + `_draw()`), не по паттерну `walker.gd`.

### 6. Экономика

```gdscript
# scripts/economy.gd
class_name Economy extends RefCounted
signal changed(kind: String, amount: int)
var wood := 0; var ore := 0; var gold := 0
func can_afford(cost: Dictionary) -> bool
func spend(cost: Dictionary) -> bool
func add(kind: String, amount: int) -> void
```
Владелец — `scripts/player_state.gd` (`class_name PlayerState extends Node`): `team`, `economy`, `squad`, `buildings`. Два `PlayerState` под корнем матча — человек и ИИ. Никто не мутирует чужой `PlayerState` напрямую — важно и для п.11.

### 7. Карта

Не отдельный редактор уровней — карта как данные:
```gdscript
# scripts/map_data.gd
class_name MapData extends Resource
@export var floor_size := Vector2(900.0, 560.0)
@export var tree_positions: Array[Vector2]
@export var vein_positions: Array[Vector2]
@export var gold_positions: Array[Vector2]
@export var player_base: Vector2; var enemy_base: Vector2
@export var player_rally: Vector2; var enemy_rally: Vector2
```
Хранится как `.tres` в `resources/maps/` (например `skirmish_small.tres`), правится через инспектор. `scripts/map_builder.gd` (`extends Node2D`, `@export map: MapData`) в `_ready()` расставляет деревья/жилы/базы/здания по данным. Новая сцена `scenes/main/Skirmish.tscn` строится через `MapBuilder` — `Main.tscn` не трогаем. Несколько карт = несколько `.tres`, а не новые сцены.

### 8. Меню и HUD

Единственный автозагружаемый синглтон верхнего уровня — `GameState` (`scripts/game_state.gd`): держит оба `PlayerState`, активный `MapData`, состояние победы/поражения. HUD и меню общаются только с `GameState`, не лезут в дерево сцены напрямую — правильная форма и для будущей сети.

- `scenes/ui/MainMenu.tscn` (Control): Start/Quit, `change_scene_to_file("res://scenes/main/Skirmish.tscn")`.
- `scenes/ui/Hud.tscn` (CanvasLayer, по аналогии с `DebugPanel`) + `scripts/ui/hud.gd`: ресурсы, кнопки найма (→ `queue_unit`), счётчик юнитов, кнопка "в атаку"/"сбор" (→ `Squad.rally/attack_move`).
- `run/main_scene` в `project.godot` — решить отдельно перед M6: оставить `Main.tscn` дефолтным тестовым стендом, добавить RTS-режим как альтернативный вход.

### 9. Достижения

Второй и последний автозагружаемый синглтон — `Achievements` (`scripts/achievements.gd`), персистентность через `ConfigFile` в `user://achievements.cfg`. `unlock(id)` (идемпотентно), `track(event, data)`. Хуки — на уже существующих/добавленных сигналах, не поллинг: `PlayerBody.died` (новый сигнал, одна строка в `_start_death()`) → "первая кровь"; `Base.base_destroyed` → "первая база"; счётчик построенных `Tower`; накопленное дерево/руда через `Stockpile.add`.

### 10. ИИ-противник

`scripts/ai_director.gd` (`extends Node`, ребёнок вражеского `PlayerState`) — только цикл решений, раз в ~2 сек, **никогда не трогает симуляцию напрямую** — вызывает те же методы, что и HUD: `production_building.queue_unit(...)`, `squad.attack_move(...)`. Один код-путь "нанять юнита"/"отправить армию" на обе стороны — то, что потом превращает подстановку "сетевой игрок вместо ИИ" в замену вызова, а не переписывание.

### 11. Готовность к сети (только архитектура, без netcode)

- **Никаких `Input.*` ниже уровня команд.** `Unit/Worker/Squad/ProductionBuilding/Economy` управляются только явными вызовами методов; ввод мыши/клавиатуры транслируется в эти вызовы в HUD/`scripts/ui/player_input_adapter.gd`. Это ровно то место, где потом появился бы RPC-вызов.
- **Фиксированный словарь команд с примитивными аргументами**: `Squad.rally(Vector2)`, `Squad.attack_move(Vector2)`, `ProductionBuilding.queue_unit(String)`. Для команд "атаковать конкретного юнита"/"собирать конкретное дерево" — передавать **id**, не прямую ссылку на `Node2D`: завести в `GameState` `next_id`/`Dictionary[int, Node2D]` уже сейчас, чтобы не переделывать все вызовы потом.
- **Строгое владение состоянием по сторонам** — `PlayerState` мутирует только своё; наблюдение за противником — только через публичные `"targets"/"bases"`.
- **Случайность — только в презентации.** Существующий `randf()` (мерцание огня, покачивание походки) уже чисто визуальный. Новую геймплейную случайность (джиттер ИИ, разброс спавна) держать внутри `AIDirector`/спавна, не мешать с `Economy`/`Squad`/резолюцией боя.
- Явно НЕ делаем сейчас: `@rpc`, `MultiplayerSpawner`, `multiplayer.is_server()`.

### 12. Риск производительности — O(n²) скан целей

`Unit._who_to_watch()` (сейчас `knight.gd:98`) и будущий скан `Tower` перебирают всю группу `"targets"` каждый физ-кадр на каждого юнита/башню. При 20-60 юнитов на сторону это существенно. План:
1. **M4**: throttle — полный скан раз в ~0.2-0.3с на юнита, со сдвигом по времени при спавне (`randf() * interval`), `quarry` остаётся "липким" между сканами, как и задумано текущим кодом. Даёт >10x снижение почти бесплатно.
2. **Только если профилирование на ~60v60 покажет нехватку** (карта маленькая, 900×560 — грубая сетка дешева): `scripts/spatial_grid.gd` — `Dictionary[Vector2i, Array[Node2D]]` с ячейкой ~100px, регистрация в `_ready()`/`tree_exiting()`, запрос `nearby(pos, radius)` вместо скана группы. Запасной вариант, не делать по умолчанию.

---

## Фазы (каждая — рабочий, тестируемый результат; `Main.tscn`/`debug_panel.gd`/`PlayerBody`/`walker.gd`/`Gait` не ломаются ни на одном шаге)

- **M0 — Фундамент.** (План уже сохранён в `docs/rts_plan.md` — сделано 2026-09-24.) `team.gd`, `team`/`team_of()` на `PlayerBody`, переименование Knight→Unit. Проверка: старое поведение в `Main.tscn` не изменилось.
- **M1 — Слой команд.** `Order`/`set_rally`/`set_attack_move`/`Squad`, пока без pathfinding (движение по X, как сейчас).
- **M2 — Pathfinding.** `NavigationRegion2D`+`NavigationObstacle2D`+`NavigationAgent2D`, `_walk_towards` переписан. Проверка: юнит объезжает дерево.
- **M3 — Фракции в бою + экономика.** Команды на сценах игрока/юнитов; `Worker`, `Stockpile`, золото как `resource_kind`, `Economy`. Проверка: рабочий рубит дерево → склад получает wood; два отряда дерутся, союзников не трогают.
- **M4 — Здания.** `Base` (с сигналом разрушения), `ProductionBuilding`, `Tower`; throttle-фикс производительности. Проверка: разрушение вручную поставленной вражеской базы в тестовой сцене.
- **M5 — Данные карты.** `MapData`/`MapBuilder`/`resources/maps/*.tres`, новая `scenes/main/Skirmish.tscn`.
- **M6 — Меню/HUD/GameState.** Полный цикл: меню → старт → добыча/найм/бой → победа/поражение.
- **M7 — ИИ-противник.** `AIDirector` через тот же командный API, что и HUD. Проверка: матч ИИ-против-ИИ без участия игрока идёт до конца сам.
- **M8 — Достижения.** `Achievements` + `ConfigFile`, хуки на сигналах из M3/M4/M6.
- **M9 — Производительность и баланс.** Профилирование на целевом числе юнитов, `SpatialGrid` только при необходимости, баланс стоимостей/урона.

## Ключевые файлы

- `scripts/player.gd` — команда/team_of, публичные `nearest_tree/nearest_vein`, точка добавления сигнала `died`.
- `scripts/knight.gd` → `scripts/unit.gd` — переименование + Order/Squad-интеграция + pathfinding.
- `scripts/campfire.gd` — эталонный паттерн для `Stockpile._take_fuel`-подобного сканирования.
- `scripts/dummy.gd` — эталонный паттерн duck-typed `"targets"`-контракта для `Base`/`Tower`.
- `scenes/main/Main.tscn` — не трогать; эталон структуры для новой `Skirmish.tscn`.

## Проверка

- После M0: `Main.tscn` открывается и играется как раньше (debug_panel, все действия рыцаря/игрока).
- После M2: создать тестовую сцену с двумя `Unit` и деревом между ними — юнит доходит до цели в обход.
- После M3: два юнита разных команд дерутся, юниты одной команды — игнорируют друг друга; рабочий за N секунд приносит ресурс на склад (проверяется по `Economy.wood` в отладочном выводе). Отдельно проверить: `Economy.ore`/`Economy.gold` не меняются в момент удара киркой по жиле, а увеличиваются только после того, как рабочий физически донёс `Rock` до `Stockpile` — это верно и для рабочего игрока, и для рабочего ИИ.
- После M6: полный ручной плейтест — от меню до победы/поражения на одной карте.
- После M7: оставить матч ИИ vs ИИ без вмешательства игрока на несколько минут — проверить, что экономика растёт и происходит атака.
- Далее — ручной плейтест каждой фазы через Godot editor (F5), т.к. автоматических тестов в проекте нет.
