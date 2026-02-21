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
/assets        # graphics, audio, spritesheets
/src
  main.lua
  player.lua
  enemy.lua
  state_manager.lua
  room_generator.lua
  ui.lua
/README.md
/LICENSE
```

## Notes on implementation

* AI uses explicit finite state machines for predictable, testable behavior.
* Procedural generation uses `math.randomseed(os.time())` and table-based room grids.
* Reverse-loop removal is used for runtime object cleanup to avoid iteration bugs.

## Credits

Course project for SWGCG351 - Game Development and Design, supervised by Dr. Mohamed Sami Rakha. Affiliated with Zewail City of Science, Technology and Innovation and the University of Science and Technology.
