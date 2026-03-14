Priority is sorted by **impact on existing code** (highest to lowest), not by easiest implementation.

## Impact Legend
- **High impact**: touches core update flow and many existing systems.
- **Medium impact**: changes multiple gameplay systems but not the whole architecture.
- **Low impact**: mostly additive or localized cleanup.

## Priority Matrix (Sorted By Impact On Old Code)
| Priority | Workstream | Impact On Existing Code | Why This Impact Is High/Low | Main Requirement Gaps Closed |
|---|---|---|---|---|
| P1 | Shared world model + orchestrator + event bus | High | Rewires `states/game.lua` and system data flow | Systems map architecture, modular decoupling |
| P2 | Procedural rooms + door transitions + room-based spawn | High | Adds missing world pipeline and changes reset/spawn logic | Procedural generation, transitions, dynamic spawns |
| P3 | Progression + evacuation sequence + victory trigger | High | Replaces direct victory shortcut with staged endgame | Progression unlocks, evacuation survival |
| P4 | Explicit FSM compliance and AI/movement separation | Medium-High | Changes enemy update semantics in AI and movement | Required Idle/Patrol/Chase/Return FSM |
| P5 | Health/energy/ability ownership cleanup | Medium | Redistributes logic across systems and event flow | Resource system architecture requirements |
| P6 | Dynamic difficulty scaling integration | Medium | Adds modifier propagation to enemy/spawn systems | Time/progress/rooms difficulty scaling |
| P7 | Presentation completion (`vfx`, `messages`, audio hooks) | Low-Medium | Mostly additive with small callsite updates | Feedback/message polish requirements |
| P8 | Input/docs consistency + state/file cleanup | Low | Localized edits, no major gameplay architecture impact | Control correctness + maintainability |
| P9 | Test implementation | Low | Additive test work, low runtime risk | Required testing/debug deliverables |

---

## P1 - Shared World Model + Orchestrator + Event Bus (High Impact)
### Why this must happen first
Current gameplay state (`src/states/game.lua`) directly orchestrates many module singletons and performs gameplay decisions inline. This blocks clean integration of roomgen, progression, evacuation, and difficulty.

### Files to implement/add
- `src/world/world.lua` (currently empty)
- `src/core/events.lua` (currently empty)
- `src/states/play.lua` (currently empty, should become orchestrator)

### Files to change
- `src/states/game.lua` (either wrapper around `play.lua` or merge and rename)
- `main.lua` (state registration target)
- `src/systems/player_system.lua`
- `src/systems/enemy_system.lua`
- `src/systems/cell_system.lua`
- `src/systems/power_node_system.lua`

### Detailed implementation steps
1. Implement `World.new(context, width, height)` in `src/world/world.lua`.
2. Build world shape with explicit sections:
   - `world.player`
   - `world.entities = { drones = {}, hunters = {}, cells = {}, powerNodes = {} }`
   - `world.room`
   - `world.metrics = { elapsedTime = 0, roomsCleared = 0, cellsCollected = 0 }`
   - `world.progression`
   - `world.difficulty`
   - `world.flags = { gameOver = false, victory = false, evacuationActive = false }`
3. Implement a lightweight event queue in `src/core/events.lua`:
   - `push(eventName, payload)`
   - `drain()` returns ordered events and clears queue
4. Move central update ordering into `src/states/play.lua`:
   - Input -> AI intent -> Ability -> Movement -> Collision -> Damage/Resources -> Progression/Difficulty/Evacuation -> UI/VFX
5. Convert singleton systems to world-based API without breaking all at once:
   - `init(world, context)`
   - `reset(world, context)`
   - `update(world, dt, events)`
   - `draw(world)`
6. Keep a compatibility layer in `src/states/game.lua` that forwards to `play.lua` while migration finishes.

### Required changes to current code
- Replace module-level mutable state in `player_system`, `enemy_system`, `cell_system`, `power_node_system` with `world` references.
- Remove direct state transitions from system internals; only play state performs `StateManager.change(...)`.

---

## P2 - Procedural Rooms + Door Transitions + Room-Based Spawn (High Impact)
### Files to implement/add
- `src/world/map.lua` (currently empty)
- `src/world/room_generator.lua` (currently empty)
- `src/world/door_trigger.lua` (currently empty)
- `src/systems/roomgen_system.lua` (currently empty)
- `src/systems/spawn_system.lua` (currently empty)

### Files to change
- `src/systems/collision_system.lua`
- `src/states/play.lua` (or `game.lua` during migration)
- `src/systems/enemy_system.lua`
- `src/systems/cell_system.lua`
- `src/systems/power_node_system.lua`

### Detailed implementation steps
1. Define room data contract in `map.lua`:
   - room id, seed, bounds, obstacle rectangles, door triggers, spawn points.
2. Implement `RoomGenerator.generate(seed, progression, difficulty)` in `room_generator.lua`:
   - random layout
   - deterministic door placement
   - safe player spawn point
   - enemy/cell/node spawn anchors
3. Implement helper builders in `door_trigger.lua`:
   - create trigger rectangles by side (`north/south/east/west`)
   - opposite-side spawn mapping
4. Implement `roomgen_system.lua`:
   - on run start: create initial room
   - on door touch event: generate next room, update bounds, reposition player safely
5. Update collision system to emit `door_touched` event instead of state changes.
6. Implement `spawn_system.lua`:
   - consume `room_entered` events
   - spawn entities using room anchors + difficulty modifiers
   - avoid frame-by-frame respawn loops

### Required changes to current code
- Replace hard reset spawning in `EnemySystem.reset` and `CellSystem.reset` with spawn-system-driven population.
- Replace fixed world bounds in `game.lua` with room bounds.

---

## P3 - Progression + Evacuation + Victory Sequencing (High Impact)
### Files to implement/add
- `src/systems/progression_system.lua` (currently empty)
- `src/systems/evacuation_system.lua` (currently empty)

### Files to change
- `src/systems/power_node_system.lua`
- `src/states/play.lua` or `src/states/game.lua`
- `src/ui/hud.lua` and `src/ui/messages.lua`

### Detailed implementation steps
1. Keep node interaction/repair in `power_node_system.lua`, but stop returning direct victory.
2. Emit `power_node_repaired` events from node system.
3. Implement `progression_system.lua`:
   - track repaired node counts
   - unlock routes/room tiers
   - emit `evacuation_started` when objective threshold is met
4. Implement `evacuation_system.lua`:
   - start countdown on `evacuation_started`
   - fail if player dies before timer ends
   - set `world.flags.victory = true` when countdown completes
5. In play state, transition to victory only when `world.flags.victory` is true.

### Required changes to current code
- Remove direct `StateManager.change("transition", "victory")` on all nodes repaired.
- Add evacuation timer and objective messaging in HUD/messages modules.

---

## P4 - Explicit FSM Compliance + AI/Motion Separation (Medium-High Impact)
### Files to change
- `src/systems/ai_system.lua`
- `src/entities/patrol_drone.lua`
- `src/entities/hunter_drone.lua`
- `src/systems/enemy_system.lua`
- `src/systems/movement_system.lua` (or add `enemy_movement_system.lua`)

### Detailed implementation steps
1. Add explicit FSM constants:
   - `idle`, `patrol`, `chase`, `return`
2. Store `enemy.state` and `enemy.homeX/homeY` in entity constructors.
3. Refactor AI update:
   - AI computes `enemy.desiredVx` and `enemy.desiredVy`
   - AI performs state transitions only
4. Move final position integration out of AI:
   - movement step applies velocity with dt
5. Add return behavior:
   - when hunter loses target, go to `return` until near home, then `idle/patrol`
6. Keep pause/stun as explicit state or status effect, not implicit booleans.

### Required changes to current code
- Remove direct `enemy.x = ...` writes from `ai_system.lua`.
- Update enemy update flow in `enemy_system.lua` to call AI then movement.

---

## P5 - Resource Ownership Cleanup (Health/Energy/Ability) (Medium Impact)
### Files to implement/add
- `src/systems/health_system.lua` (currently empty)

### Files to change
- `src/systems/damage_system.lua`
- `src/systems/collision_system.lua`
- `src/systems/energy_system.lua`
- `src/systems/ability_system.lua`
- `src/systems/movement_system.lua`
- `src/states/play.lua` or `src/states/game.lua`

### Detailed implementation steps
1. Make collision system detect and emit hit events only.
2. Keep damage system focused on:
   - invulnerability timers
   - knockback impulse
   - hit events -> health delta requests
3. Implement `health_system.lua`:
   - apply health deltas
   - set death flag
   - optional regen rules
4. Expand `energy_system.lua`:
   - pickup restore
   - passive regen (if enabled)
   - spend helpers for dash/stun
5. Move dash activation from movement into `ability_system.lua` (docs expect dash ability ownership there).
6. Keep movement system only for velocity integration and impulse blending.

### Required changes to current code
- Remove energy spend and dash trigger logic from `movement_system.lua`.
- Keep `ability_system.lua` as the ability coordinator for dash + stun gun.

---

## P6 - Dynamic Difficulty Scaling (Medium Impact)
### Files to implement/add
- `src/systems/difficulty_system.lua` (currently empty)

### Files to change
- `src/systems/spawn_system.lua`
- `src/systems/enemy_system.lua`
- `src/systems/ai_system.lua`
- `src/ui/messages.lua`

### Detailed implementation steps
1. Compute difficulty score from:
   - elapsed time
   - rooms cleared
   - progression stage
2. Update difficulty at low frequency (for example every 1s), not every frame.
3. Write modifiers into `world.difficulty.modifiers`:
   - enemy speed multiplier
   - hunter detection multiplier
   - room spawn budget
4. Apply modifiers in spawn and enemy initialization/update.
5. Surface threshold warnings through UI message system.

### Required changes to current code
- Replace hard-coded patrol/hunter speeds/ranges in `enemy_system.lua` with base stats + difficulty multipliers.

---

## P7 - Presentation Completion (`vfx`, `messages`, audio hooks) (Low-Medium Impact)
### Files to implement/add
- `src/systems/vfx_system.lua` (currently empty)
- `src/ui/messages.lua` (currently empty)

### Files to change
- `src/states/play.lua` or `src/states/game.lua`
- `src/ui/hud.lua`
- `src/systems/audio_system.lua`

### Detailed implementation steps
1. Keep `screen_flash_system.lua` as one effect node; orchestrate through `vfx_system.lua`.
2. Implement `messages.lua` for:
   - cooldown/energy warnings
   - progression prompts
   - evacuation status
   - difficulty escalation notices
3. Route gameplay events to audio/vfx hooks:
   - cell pickup (currently configured but not used)
   - node repair tick/complete
   - evacuation start
4. Keep presentation read-only relative to gameplay state.

### Required changes to current code
- Add event emission for pickup/repair milestones so audio and messages can subscribe.

---

## P8 - Input/Docs Consistency + Module Cleanup (Low Impact)
### Files to change
- `src/systems/input_system.lua`
- `README.md`
- `main.lua` config comments
- `src/core/stateManager.lua` (empty duplicate)

### Detailed implementation steps
1. Add Arrow key movement support in `InputSystem.getMoveDir()`.
2. Add `e` key for interact to match docs.
3. Decide one canonical playing state file (`play.lua` or `game.lua`) and remove ambiguous duplicate pattern.
4. Remove or repurpose empty duplicate files that confuse ownership.

### Required changes to current code
- Small input mapping updates and README control sync.

---

## P9 - Tests and Regression Harness (Low Impact)
### Files to implement/add
- `tests/collision_test.lua`
- `tests/ai_test.lua`
- `tests/room_generation_test.lua`

### Detailed implementation steps
1. Collision tests:
   - AABB overlap true/false cases
   - separation resolution direction
2. AI tests:
   - patrol waypoint flipping
   - hunter state transitions (`idle -> chase -> return`)
3. Roomgen tests:
   - generated room has valid doors/spawn points
   - safe player spawn is inside bounds and outside obstacles
4. Add deterministic seed fixtures for repeatable test runs.

---

## Separation of Concerns and Abstraction Recommendations
1. Use a single `world` table as runtime source of truth instead of system-level module globals.
2. Keep systems pure by responsibility:
   - Input writes intent.
   - AI writes desired movement/state.
   - Movement integrates position.
   - Collision resolves and emits events.
   - Damage/Health/Energy apply resource effects.
3. Use event-driven side effects for audio/VFX/UI messages.
4. Avoid direct cross-system calls where possible. Prefer state orchestrator + shared world + events.
5. Consolidate constants in `src/utils/constants.lua` and remove duplicate hard-coded values across systems.
6. Keep entity constructors data-only. Move runtime behavior to systems.
7. Avoid hidden singleton state in systems for easier tests and deterministic resets.
8. Make one canonical state-manager file and one canonical play state file.
9. Keep transition logic state-only; systems should never trigger state changes directly.
10. Add typed contracts in comments for shared structures (`world`, `room`, `event payloads`).

---

## Concrete Changes Needed In Current Code To Support New Systems
1. Replace direct win transition in `src/states/game.lua` with progression/evacuation flags.
2. Replace static spawn on reset with room-enter spawn events.
3. Move dash activation out of movement and into ability system.
4. Stop AI from moving enemies directly; movement system handles integration.
5. Introduce room bounds and door triggers into collision stage.
6. Convert audio trigger calls in gameplay logic into event-driven playback where feasible.
7. Add missing modules currently empty, then wire them in state update order.

---

## Suggested Execution Sequence (Practical)
1. P1
2. P2
3. P3
4. P4
5. P5
6. P6
7. P7
8. P8
9. P9

This order minimizes rework: architecture first, then world/progression flow, then behavior tuning/presentation/tests.
