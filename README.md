## Eclipse Protocol - Top-Down Sci-Fi Survival

**Eclipse Protocol** is a procedurally generated top-down survival game that challenges the player to manage energy and health while repairing power nodes and evading hostile drones. The project demonstrates clean, modular Lua architecture, state-driven AI, and polished UX.

## Key features

* Velocity-based player movement with dash and cooldown
* Health, energy, and UI (bars + messages)
* Two enemy archetypes with FSM-driven behaviors (patrol & hunter)
* AABB collision, knockback, and invulnerability frames
* Procedural room generation and dynamic spawning
* Difficulty scaling (speed, spawn rate, detection range)
* Sprite-sheet animation, background music, and multiple SFX
* Modular codebase (multiple Lua files) and GitHub-friendly structure

## Requirements

* Lua 5.1+ and Love2D runtime.
* Tested with Love2D (see engine docs for platform-specific setup). Love2D

## Quick start

1. Clone the repository:
   `git clone [<repo-url>](https://github.com/Momen-Sanad/EclipseProtocol/)`
2. Run with Love2D:
   `love .`
   (Or follow your OS-specific method to launch the folder in Love2D.)

## Controls

* Move: Arrow keys / WASD
* Dash: Space (consumes energy, has cooldown)
* Interact / Repair: E or Enter
* Pause: Esc

## Project structure (in-progress)

```
.
├── LICENSE
├── README.md
├── conf.lua
├── main.lua
│
├── assets/
│   ├── background.png
│   ├── sprites/
│   │   ├── parrot.png
│   │   ├── player/
│   │   ├── enemies/
│   │   ├── items/
│   │   └── ui/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   ├── fonts/
│   └── shaders/
│
├── Docs/
│   ├── Dev Systems.md
│   ├── Project goals.md
│   ├── Systems Map.md
│   └── Workload Divison.md
│
├── src/
│   ├── core/
│   │   ├── game.lua                 # Central loop helpers (optional)
│   │   ├── stateManager.lua         # Game State Manager (Menu/Play/Pause/Over/Victory)
│   │   ├── events.lua               # Event queue (push/consume helpers)
│   │   ├── collision.lua            # AABB helpers (pure functions)
│   │   └── timer.lua                # Cooldowns/timers helpers
│   │
│   ├── world/
│   │   ├── world.lua                # WORLD DATA (the shared passive table)
│   │   ├── map.lua                  # Room/map data representation
│   │   ├── room_generator.lua       # Procedural room generation (writes room data)
│   │   └── door_trigger.lua         # Door trigger definitions (data + helpers)
│   │
│   ├── states/
│   │   ├── menu.lua                 # Start Menu state
│   │   ├── play.lua                 # Central Orchestrator (owns world + systems list + order)
│   │   ├── pause.lua                # Pause state
│   │   ├── gameover.lua             # Game Over state
│   │   └── victory.lua              # Victory state
│   │
│   ├── entities/
│   │   ├── player.lua               # Player data factory/defaults
│   │   ├── enemy_base.lua           # Shared enemy defaults
│   │   ├── patrol_drone.lua         # Patrol Drone data factory
│   │   ├── hunter_drone.lua         # Hunter Drone data factory (FSM fields)
│   │   ├── energy_cell.lua          # Collectible item data factory
│   │   └── power_node.lua           # Power node interactable data factory
│   │
│   ├── systems/
│   │   ├── input_system.lua         # 1) Input System (writes intent)
│   │   ├── ai_system.lua            # 2) AI System (FSM -> writes enemy intent/state)
│   │   ├── movement_system.lua      # 3) Movement System (vel -> pos integration)
│   │   ├── collision_system.lua     # 4) Collision System (AABB -> writes events/flags)
│   │   ├── damage_system.lua        # 5) Damage & Invulnerability (reads collision events)
│   │   ├── resource_system.lua      # 6) Resources (health/energy/time regen)
│   │   ├── ability_system.lua       # 7) Dash (reads input intent + energy)
│   │   ├── spawn_system.lua         # 8) Spawn (enemies/items create + cleanup)
│   │   ├── roomgen_system.lua       # 9) Procedural Room Gen trigger (on transitions)
│   │   ├── progression_system.lua   # 10) Power nodes / unlocking rules
│   │   ├── difficulty_system.lua    # 11) Dynamic difficulty (low frequency)
│   │   ├── evacuation_system.lua    # 12) Evacuation timer/progress
│   │   ├── animation_system.lua     # 13) Animation (read-only gameplay)
│   │   ├── hud_system.lua           # 14) UI/HUD (read-only gameplay)
│   │   ├── audio_system.lua         # 15) Audio (reads events only)
│   │   └── vfx_system.lua           # 16) Visual feedback (flicker/shake; read-only gameplay)
│   │
│   └── utils/
│       ├── vector.lua               # Vector helpers
│       ├── constants.lua            # Global constants/tunables
│       └── math_utils.lua           # Small math helpers
│
└── tests/
    ├── collision_test.lua
    ├── ai_test.lua
    └── room_generation_test.lua
```

## Notes on implementation

* AI uses explicit finite state machines for predictable, testable behavior.
* Procedural generation uses `math.randomseed(os.time())` and table-based room grids.
* Reverse-loop removal is used for runtime object cleanup to avoid iteration bugs.

## Credits

Course project for SWGCG351 - Game Development and Design, supervised by Dr. Mohamed Sami Rakha. Affiliated with Zewail City of Science, Technology and Innovation and the University of Science and Technology.
