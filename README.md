# Mech Hero

An isometric mech-vs-kaiju roguelite shooter, inspired by Archero's stage-by-stage
upgrade loop, Japanese mecha and giant-monster films. You pilot a towering mech
through a neon city at night, clearing waves of enemy machines in bullet-hell fights
while the city comes down around you. Between stages you pick one of three upgrades.
Stage 10 is a kaiju.

Built with **Godot 4.5** (GDScript). Everything is made from primitives, shaders and
particles, so there are no art assets.

## Running

1. Install [Godot 4.5](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in the editor and press **F5**, or run `godot --path .`.

## Controls

| Action | Keyboard + mouse | Gamepad |
| --- | --- | --- |
| Move | WASD / arrows | Left stick |
| Aim | Mouse | Right stick |
| Fire | Hold left mouse | Right stick (auto-fires) or RT |
| Boost dash (i-frames) | Space / Shift / right mouse | A / LB / RB / LT |
| Pause | Esc / P | Start |
| Pick upgrade | 1 / 2 / 3 or click | D-pad + A |

## The loop

- **10 stages** across six district types, an elite strike group on stage 5, and
  the kaiju **Leviathan** on stage 10:
  - **Rural**: one crossroads through crop fields, farmsteads with barns and silos, hay bales.
  - **Mixed**: suburban houses with pitched roofs, gardens, a few mid-rise blocks.
  - **Forest**: dense pines with clearings, cabins and fire watchtowers. Little hard cover.
  - **Downtown**: dense neon towers. **Harbor**: container stacks and warehouses.
    **Highway**: wide roads, heavy traffic, sparse industry.
- Enemies drop from orbit in waves. Clear them all, then walk into the green
  **extraction gate** to pick **1 of 3 upgrades** (18 in the pool, most stackable),
  repair 20% hull, and move on.
- **Enemies**: drones (kamikaze), walkers (aimed bursts), spinners (spiral
  bullet-hell), lancers (telegraphed charges that plough through buildings),
  mortars (lobbed shells with ground markers).
- **Leviathan**: three phases of rings, fans, stomps, spirals, drone summons and a
  sweeping laser. It wades straight through the city.

## The city is the third combatant

- Buildings block bullets from **both** sides, so they work as destructible cover.
  They crack, their windows die, they smoke and then collapse into rubble.
- Mechs grind through buildings they push into (boost dashing does it faster) and
  crush cars, lamps, trees and kiosks underfoot. Some cars explode and hurt nearby
  enemies.
- Wreckage drops green energy shards that repair your hull.
- The **collateral damage** counter (top right) keeps score in yen.
- The *Demolisher* and *Rampage* upgrades reward wrecking things.

## Project layout

```
autoload/      game_state (run, stats, power-ups, input map), world (registries,
               spatial grid, explosions), bullet_manager (pooled MultiMesh bullets), fx
data/          powerups.gd, stages.gd  ← most tuning lives here
scenes/
  run/         run flow, iso camera, lighting
  arena/       arena + procedural city generator
  destructibles/ building, prop, debris pool
  player/      player mech + weapon
  enemies/     enemy_base + 5 enemy types, mortar shell, Leviathan boss
  mechs/       mech_builder: models built from primitives
  ui/          HUD, upgrade cards, pause, end screen, title screen
shaders/       ground roads, building facades, bullets, glow, telegraphs
tests/         headless smoke test, parse check, screenshot capture
docs/          iteration plan
```

## Tests

```sh
# Compile every script with autoloads active
godot --headless --path . res://tests/parse_check.tscn
# Play through the core systems: city gen, shooting, destruction, waves, gate,
# upgrades, bullet stress test (~2000 bullets), all three boss phases, victory
godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
# Save screenshots of a scripted run (needs a display, e.g. xvfb-run)
godot --path . --fixed-fps 60 res://tests/screenshot.tscn -- /tmp/shots
```
