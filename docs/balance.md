# Баланс: где что крутить

Все игровые числа лежат в таблицах и константах. Здесь собрано, какой файл отвечает за что. Номера строк — на 2026-09-26.

## Экономика
| Что | Где |
|---|---|
| Найм рабочих и новобранцев, время обучения в казарме | `scripts/production_building.gd:12` `CATALOG`, `:44` `TRAIN_TIME` |
| Оружие и снаряжение: цена и время ковки | `scripts/forge.gd:18` `GEAR`, `:47` `BLOW_WORK` (сколько работы даёт удар молота) |
| Постройки: цена, время стройки, лимиты | `scripts/game_state.gd:22` `BUILDINGS`; работа одного удара строителя: `scripts/building.gd:49` `BUILD_BLOW` |
| Исследования: цена, время, эффекты | `scripts/player_state.gd:18` `RESEARCH` |
| Ремонт: прочность за удар и цена | `scripts/building.gd:143` `REPAIR_HP`, `REPAIR_COST` |
| Ресурсы карты: запас жил, брёвна с дерева, восстановление, стартовый склад | `resources/maps/*.tres`: `ore_rocks`, `ore_rock_worth`, `gold_*`, `tree_logs`, `log_worth`, `regrow_time`, `start_stock` |
| Лагеря разбойников: состав и сундук | в карте: `camp_bandits`, `camp_bounty`; радиус охраны: `scripts/bandit_camp.gd:15` `GUARD` |

## Бой
| Что | Где |
|---|---|
| Виды бойцов: здоровье, навык, дальность, осада, скорость | `scripts/unit.gd:41` `LOADOUTS` |
| Урон оружия и его цена в выносливости | `scripts/player.gd:149` `STRIKE_HARM`, `:116` `STRIKE_COST` |
| Защита шлема, лат, щита | `scripts/unit.gd:310` `HELM_GUARD`, `ARMOUR_GUARD`, `SHIELD_GUARD` |
| Звёзды: убийства и бонусы | `scripts/unit.gd:138` `STARS_AT`, `STAR_HARM`, `STAR_HEALTH` |
| Башня | `scripts/tower.gd:7` `RANGE`, `DAMAGE`, частота выстрелов рядом |
| Зрение в бою | `scripts/unit.gd:15` `SIGHT`, `LOSE_SIGHT`, `LEASH` |
| Туман: обзор по видам | `scripts/fog_of_war.gd:26` `UNIT_VISION`, `KIND_VISION` и ниже |
| Погода: сутки, ночь, дождь | `scripts/weather.gd:23` (`DAY_END`…), `:28` `NIGHT_SIGHT`, `RAIN_BOW`, `RAIN_FIRE`… |
| Сколько лежат тела и трофеи | `scripts/player.gd:254` `CORPSE_LIFE`, `scripts/trophy.gd:8` `LIFE` |

## ИИ
| Что | Где |
|---|---|
| Стратегии: рабочие, волны, исследования, смесь войск, башни | `scripts/ai_profile.gd:9` `STRATEGIES` |
| Уровни сложности, в том числе задержки | `scripts/ai_profile.gd:74` `DIFFICULTIES` (смысл каждого поля описан в комментарии над таблицей) |

Задержки ИИ (секунды), которые задаются в `DIFFICULTIES`:
- `react` — сколько он замечает врага у своих стен;
- `muster` — сколько собранная волна ждёт перед выходом;
- `retreat` — сколько разбитая волна ещё дерётся, прежде чем её отзовут;
- `study_pause` — пауза между исследованиями.

Сейчас на «Обычном»: думает в 1,3 раза медленнее стратегии, крупнейшая волна ×0,85, первая атака на 60 с позже, реакция 2 с, сбор волны 10 с, отход 3 с, пауза между исследованиями 12 с.
