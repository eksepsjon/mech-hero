# Mech Hero — Iteration 1 Plan (Vertical Slice)

## Context
A brand-new game in an empty repo (`eksepsjon/mech-hero`, only README + .gitignore). The concept: Archero-style stage-by-stage roguelite with Pacific Rim / Japanese mecha flavor. Isometric camera (Diablo-like), WASD + mouse aim or twin-stick gamepad, and you pick one of three power-ups between stages to get stronger. Visuals should be bright and busy, close to bullet hell.

Decisions made: **Godot 4 (GDScript)**, **low-poly 3D built from primitives plus neon/bloom FX** (no art assets), scope = **vertical slice** (1 mech, 4–5 enemies, 1 boss, 10 stages, ~15 power-ups, full run loop).

## Core design (iteration 1)
- **Run**: 10 stages. Stages 1–4 and 6–9 are combat arenas, stage 5 is an elite wave, stage 10 is the boss (a giant kaiju). Clear all enemies → gate opens → power-up choice (pick 1 of 3) → next stage. Death = run over → results screen → restart.
- **Player mech**: move with WASD or the left stick, aim with the mouse or the right stick, auto-fire while aiming (holding fire / right stick deflection). Dash on Space / RB with i-frames and a cooldown. HP bar, brief invulnerability after a hit.
- **Unlike Archero**: you can shoot while moving. That keeps it action-heavy and suits twin-stick play.
- **Enemies** (each a composition of primitives, with an emissive "eye"/core):
  1. *Drone*: fast chaser that deals contact damage.
  2. *Turret Walker*: slow, fires aimed 3-shot bursts.
  3. *Spinner*: stationary, fires rotating spiral bullet patterns (the bullet-hell element).
  4. *Lancer*: telegraphs a line, then charges.
  5. *Mortar*: lobs AoE shells with a ground marker.
  - **Boss – Kaiju "Leviathan"**: 3 phases (radial bursts → spiral + summon drones → enraged laser sweep + dense rings).
- **Power-ups** (~15, defined as data, some stackable): Multishot (+1 front projectile), Diagonal shots, Rear shot, Ricochet (bounce off walls), Piercing, Attack speed +, Damage +, Crit chance, Max HP + heal, Dash cooldown −, Orbiting shield drones, Homing missiles salvo, Chain lightning on hit, Burn (DoT), Lifesteal on kill. The selection is weighted random, excluding power-ups that are maxed out.

## Scale & destructible city (core pillar)
The mechs and kaiju must feel **huge**, so every arena is a city district that gets wrecked during the fight.
- **Arenas = city blocks**: roads with lane markings, sidewalks, office towers, small shops, parked and driving cars, street lamps, trees, traffic lights and billboards. Three arena variants (downtown, harbor/docks, highway interchange), each with a procedurally scattered layout so stages differ.
- **Scale cues**: the player mech is ~6× building-floor height. Cars are toy-sized next to its feet, and towers only reach its chest or shoulders. Window grids on buildings (emissive shader) make the floor count readable. The kaiju boss towers over the tallest buildings.
- **Destruction**:
  - *Small props* (cars, lamps, trees, signs): the mech or enemies crush them by walking through. They pop into a few tumbling debris pieces and a spark burst. Cars can explode (small AoE that hurts enemies → emergent tactics).
  - *Buildings*: they have HP and block bullets (destructible cover for both sides). On damage they crack, windows flicker and smoke appears. On death they collapse: the mesh sinks plus a burst of pre-chunked debris rigid bodies, a big dust cloud and screen shake, leaving a rubble pile behind (low, walkable, no longer cover). Boss attacks and the Lancer charge level buildings in their path.
  - Footsteps: dust puffs, light camera shake, and cracks in the road under heavy enemies and the boss.
- **Payoff**: a "Collateral" meter/score shown on the HUD. Destroyed objects drop small energy shards that heal a little or charge the dash, so smashing the city is rewarded. Two power-ups use this: *Demolisher* (bullets do bonus damage to structures, and collapses damage nearby enemies) and *Rampage* (crushing props briefly boosts fire rate).
- **Performance budget**: buildings are `StaticBody3D` with simple box colliders. Debris lives in a pooled set of `RigidBody3D` chunks (cap of ~150 active, 3–5 s life, then fade or sleep into rubble). Windows come from a shader, not geometry. Props are instanced through a shared mesh library.

## Architecture
Godot 4.5 project at the repo root. Data-driven design: enemies, power-ups and stages are `Resource` (.tres) files, so later content is mostly data.

```
project.godot                 # input map, autoloads, Forward+ renderer, glow on
autoload/
  game_state.gd               # run state: stage index, player stats, owned power-ups, RNG seed
  bullet_manager.gd           # pooled bullets (see Performance)
  fx.gd                       # screen shake, hit-stop, particle spawn helpers
scenes/
  main_menu.tscn / .gd
  run.tscn / run.gd           # stage flow controller: load arena → spawn waves → clear → choice → next
  arena/arena.tscn/.gd        # city block: roads, boundary, exit gate, layout generator
  arena/city_generator.gd     # scatters buildings/props per arena variant + seed
  destructibles/destructible.gd   # HP, damage states, crush-on-contact, collapse → debris + rubble
  destructibles/{building_tower,building_shop,car,lamp,tree,billboard}.tscn
  destructibles/debris_pool.gd    # pooled RigidBody3D chunks
  player/player_mech.tscn/.gd # movement, aim, dash, weapon component
  player/weapon.gd            # reads stats, emits patterns via BulletManager
  enemies/enemy_base.gd       # HP, hit flash, death FX, drop, AI state hook
  enemies/{drone,walker,spinner,lancer,mortar}.tscn/.gd
  enemies/boss_leviathan.tscn/.gd
  ui/hud.tscn                 # HP, stage x/10, boss bar
  ui/powerup_choice.tscn      # 3 cards, keyboard/mouse/gamepad navigable
  ui/game_over.tscn
resources/
  powerup.gd   (class_name PowerUp: id, name, desc, icon_color, max_stacks, apply(stats))
  enemy_def.gd, stage_def.gd (waves: [{enemy, count, delay}], arena variant)
  powerups/*.tres, stages/stage_01..10.tres
shaders/
  neon_emissive.gdshader, road.gdshader, building_windows.gdshader, hit_flash.gdshader
```

### Key technical choices
- **Isometric camera**: a `Camera3D` with orthographic projection, rotated 45° yaw / ~35° pitch, following the player smoothly. Aim = ray from the mouse onto the ground plane (y=0). On gamepad, rotate the right-stick vector by the camera yaw so "up" on the stick means up on screen. The same transform applies to movement input.
- **Input**: Godot InputMap actions (`move_*`, `aim_*`, `fire`, `dash`, `ui_*`). Switch input mode automatically based on the last device used. Hide the mouse cursor on gamepad.
- **Performance for bullet hell**: bullets are **not** nodes. `BulletManager` keeps flat arrays (position, velocity, radius, damage, owner team, lifetime, flags) and renders them with one `MultiMeshInstance3D` per bullet look (unshaded emissive spheres/capsules). It does its own circle-vs-circle collision against players and enemies each physics tick. A simple spatial grid is added only if needed. Target: 1500+ bullets at 60 fps.
- **Juice / "bright & busy"**: WorldEnvironment glow/bloom with HDR emissive materials, a night city with neon signs and emissive windows, team colors (player = cyan/white, enemies = magenta/orange), GPUParticles3D for muzzle flash, hits, explosions and dash trails, plus screen shake, a ~40 ms hit-stop on big hits, damage numbers and an enemy white flash on hit.
- **Stats model**: `PlayerStats` (damage, fire_rate, projectile counts per direction, pierce, bounces, crit, max_hp, dash_cd, on-hit effects list). Power-ups modify the stats, and the weapon reads the stats each shot. That way stacking works without special cases.

## Milestones (build order)
1. **Skeleton**: project.godot, input map, iso camera, arena floor, player movement + aim (both input schemes), dash.
2. **Combat core**: BulletManager, player weapon, enemy_base, Drone + Walker, damage/death, HUD HP.
2b. **City & destruction**: city generator, buildings/props, bullet-vs-building collision, crush props on contact, collapse + debris pool + rubble, collateral meter.
3. **Run loop**: stage_def resources, wave spawner, clear → gate → power-up choice UI → next stage, game over / victory, main menu.
4. **Content**: Spinner, Lancer, Mortar, all ~15 power-ups, stages 1–10 tuned with rising difficulty.
5. **Boss**: Leviathan, 3 phases, boss HP bar, intro moment.
6. **Juice pass**: bloom, particles, shake, hit-stop, flashes, damage numbers, bullet colors and shapes. (Audio is out of scope for iteration 1; placeholder hooks only.)

## Out of scope for iteration 1
Meta-progression or persistent upgrades, multiple mechs, audio/music, save files, real art assets, mobile controls, web export polish.

## Verification
- Download the Godot 4.5 Linux binary (GitHub release, reachable via the proxy) into the scratchpad. Run `godot --headless --import` and `godot --headless --check-only` / a script parse pass to catch GDScript errors.
- Add a small headless smoke test (`tests/smoke_test.gd`, run with `godot --headless -s`): instantiate run.tscn, simulate N seconds with scripted input, and assert that the player spawns, bullets get created and collide, a building takes damage and collapses, a car gets crushed, an enemy dies, a stage clears, and the power-up choice appears and applies stats.
- Run a BulletManager stress check headless (spawn 2000 bullets, measure tick time).
- Take screenshots by running with a virtual display (xvfb, if available) to sanity-check visuals. Final feel testing is done by you locally in the Godot editor (F5).
- Commit per milestone and push to `claude/loving-planck-pjyafj`.
