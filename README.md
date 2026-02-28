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
├── assets/                           # Game assets (images, audio, fonts, shaders)
│   ├── audio/                        # Audio files used by audio_system
│   │   ├── music/                    # Background music tracks
│   │   └── sfx/                      # Sound effects (dash, hit, pickup, etc.)
│   ├── background.png                # Background image (menu/game scenes)
│   ├── fonts/                        # Font files for UI text
│   ├── shaders/                      # GLSL shaders (optional visuals/lighting/post FX)
│   ├── sprites/                      # All sprite textures
│   │   ├── enemies/                  # Enemy sprites (patrol/hunter variants)
│   │   ├── items/                    # Collectibles / power node / pickups sprites
│   │   ├── parrot.png                # Placeholder sprite (temporary/prototyping)
│   │   └── player/                   # Player animation frames / spritesheets
│   └── ui/                           # UI images (icons, panels, bars, etc.)
│
├── conf.lua                          # Love2D config (window size, title, vsync, etc.)
├── main.lua                          # Love2D entry point: loads state manager, delegates update/draw
├── README.md                         # Project overview + how to run + architecture summary
├── LICENSE                           # Repository license
│
├── Docs/                             # Project documentation (design + planning)
│   ├── Dev Systems.md                # Dev notes on systems/modules responsibilities
│   ├── Project goals.md              # Target gameplay goals + success criteria
│   ├── Systems Map.md                # High-level architecture diagram/notes
│   └── Workload Divison.md           # Task split (if team) / personal plan (if solo)
│
├── src/                              # Source code (Lua)
│   ├── core/                         # Engine-like shared infrastructure (pure helpers / managers)
│   │   ├── collision.lua             # Pure AABB helpers (overlap checks, rect utils)
│   │   ├── events.lua                # Event queue helpers (push/consume gameplay events)
│   │   ├── game.lua                  # Game bootstrap helpers (optional wrapper around play state)
│   │   ├── stateManager.lua          # Global game state machine (menu/play/pause/over/victory)
│   │   └── timer.lua                 # Timer/cooldown helpers (dash cooldown, invulnerability timers)
│   │
│   ├── world/                        # World data + procedural generation (shared passive state)
│   │   ├── world.lua                 # Creates/holds the world table (player, enemies, rooms, flags)
│   │   ├── map.lua                   # Room/map representation (grid, boundaries, walkable areas)
│   │   ├── room_generator.lua        # Procedural room layout generation + door placement rules
│   │   └── door_trigger.lua          # Door trigger zones + transition definitions (data + helpers)
│   │
│   ├── entities/                     # Entity “constructors” / defaults (data, hitboxes, stats)
│   │   ├── player.lua                # Player data defaults (speed, health, energy, hitbox, anim)
│   │   ├── enemy_base.lua            # Shared enemy defaults (hp, speed, hitbox helpers)
│   │   ├── patrol_drone.lua          # Patrol drone factory (path points, patrol params)
│   │   ├── hunter_drone.lua          # Hunter drone factory (FSM fields, detection range, chase params)
│   │   ├── energy_cell.lua           # Energy pickup definition (value, collision box, sprite)
│   │   └── power_node.lua            # Power node interactable (repair progress, unlock flags)
│   │
│   ├── states/                       # High-level game states (activate systems, control flow)
│   │   ├── menu.lua                  # Start menu state (start game, instructions, etc.)
│   │   ├── play.lua                  # Central orchestrator: owns world + system list + update order
│   │   ├── pause.lua                 # Pause state (freezes simulation, shows pause UI)
│   │   ├── gameover.lua              # Game over state (restart/quit)
│   │   └── victory.lua               # Victory state (final time/score, replay)
│   │
│   ├── systems/                      # Systems that update the world (logic) + presentation systems
│   │   ├── input_system.lua          # Reads input -> writes player intent (moveDir, dashRequested)
│   │   ├── ai_system.lua             # Enemy FSM transitions -> writes enemy intent/desiredVelocity
│   │   ├── ability_system.lua        # Dash logic + cooldowns + energy cost -> writes velocity changes
│   │   ├── movement_system.lua       # Integrates velocity -> position using dt (no collision)
│   │   ├── collision_system.lua      # AABB checks/resolution -> writes events (enemyHit, doorTouched)
│   │   ├── damage_system.lua         # Applies damage + invulnerability + knockback using events
│   │   ├── health_system.lua         # Health rules (death flag, regen if any) using world data/events
│   │   ├── energy_system.lua         # Energy regen/consumption + caps using world data/events
│   │   ├── progression_system.lua    # Power node repair + unlocking logic -> writes progression flags
│   │   ├── difficulty_system.lua     # Difficulty scaling (based on time/rooms) -> writes modifiers
│   │   ├── spawn_system.lua          # Spawns enemies/items when entering rooms / scaling triggers
│   │   ├── roomgen_system.lua        # Handles room transition: generates next room + safe spawn points
│   │   ├── evacuation_system.lua     # Evacuation countdown + win trigger flag when active
│   │   ├── animation_system.lua      # Updates animation frames from movement/action flags (read-only)
│   │   ├── audio_system.lua          # Plays music/SFX based on events (read-only gameplay)
│   │   └── vfx_system.lua            # Visual feedback (flicker/shake/flash) from events (read-only)
│   │
│   ├── ui/                           # UI components (drawing only, no gameplay mutations)
│   │   ├── hud.lua                   # HUD layout renderer (calls bars + messages)
│   │   ├── health_bar.lua            # Draws health bar from world.player.health
│   │   ├── energy_bar.lua            # Draws energy bar from world.player.energy
│   │   └── messages.lua              # Draws messages (cooldowns, alerts, game state text)
│   │
│   └── utils/                        # Small reusable helpers (no game state)
│       ├── vector.lua                # Vector ops (normalize, length, add, scale)
│       ├── math_utils.lua            # Clamp, lerp, random helpers, etc.
│       └── constants.lua             # Tunables (speeds, detection ranges, costs, UI sizes)
│
└── tests/                            # Lightweight tests/sim checks (optional but helpful)
    ├── collision_test.lua            # Tests AABB overlap/resolution functions
    ├── ai_test.lua                   # Tests FSM transitions for hunter/patrol behavior
    └── room_generation_test.lua      # Tests procedural room generation outputs/constraints
```

## Notes on implementation

* AI uses explicit finite state machines for predictable, testable behavior.
* Procedural generation uses `math.randomseed(os.time())` and table-based room grids.
* Reverse-loop removal is used for runtime object cleanup to avoid iteration bugs.

## Credits

Course project for SWGCG351 - Game Development and Design, supervised by Dr. Mohamed Sami Rakha. Affiliated with Zewail City of Science, Technology and Innovation and the University of Science and Technology.
