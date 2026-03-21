# Prioritized Fix Plan (Updated 2026-03-22)

This revision reflects the current gameplay/runtime state through commit `27fdf82`.
Priority order remains sorted by **impact on existing code** (highest to lowest).

## Status Legend
- `Done`: Implemented and integrated.
- `Scoped-Done`: Implemented for current game-design scope; optional architecture/spec polish remains.
- `Partial`: Significant pieces implemented, but requirement/architecture still incomplete.
- `Pending`: Not implemented yet.

## Priority Snapshot (By Impact On Existing Code)

| Priority | Workstream | Impact On Existing Code | Current Status |
|---|---|---|---|
| P1 | Shared world model + orchestrator + event bus | High | Scoped-Done |
| P2 | Procedural rooms + door transitions + room-based spawn | High | Scoped-Done |
| P3 | Progression + evacuation sequence + victory trigger | High | Scoped-Done |
| P4 | FSM compliance and AI/movement separation | Medium-High | Scoped-Done |
| P5 | Health/energy/ability ownership cleanup | Medium | Done |
| P6 | Difficulty scaling integration | Medium | Partial |
| P7 | Presentation completion (`vfx`, `messages`, event hooks) | Low-Medium | Partial |
| P8 | Input/docs consistency + state/file cleanup | Low | Partial |
| P9 | Tests and regression harness | Low | Pending |

---

## Completed Since Last Revision

### P1 foundation and orchestration
- Added shared runtime world container in `src/world/world.lua`.
- Added event queue primitive in `src/core/events.lua`.
- Moved canonical runtime orchestration into `src/states/play.lua`.
- Converted `src/states/game.lua` into a compatibility forwarder to `play.lua`.
- Added incremental world-sync hooks across systems.

### P2 room generation and transitions
- Added procedural map + room pipeline (`src/world/map.lua`, `src/world/room_generator.lua`, `src/world/door_trigger.lua`).
- Integrated room-generated doors and spawn anchors into play flow.
- Preserved exact door continuity across transitions:
  - exiting through door position `Z` in room `N` produces entry door position `Z` in room `N+1`
  - player spawn continuity is anchored to that entry position.
- Enforced safe transition entry spawn at generation time.
- Enforced enemy overlap constraints between patrol and hunter spawn sets.
- Kept doors edge-bound and prevented new exit door reuse of incoming edge slot.

### AI and obstacle behavior polish
- Made power-node collisions frictionless for player and drones (ice-like sliding).
- Restored reroute detection when AI is sliding (position changes no longer suppress reroute trigger).
- Diversified reroute choices after failed unstuck attempts.
- Increased reroute clearance distance to reduce edge bounce around power nodes.

### P6 gameplay pressure additions
- Added health-scaled movement impairment in `movement_system`:
  - movement speed penalty at low health
  - directional drift/sway and intermittent stumble behavior
  - small render shake that scales by health and remains mild enough for repairs.

### Debug and tuning updates
- Added visible hollow player hitbox debug draw.
- Aligned player sprite rendering anchor to hitbox center.
- Tightened default hitbox sizing to better match sprite footprint while keeping config overrides.

---

## Remaining Work (Still Needed)

### P1 - Shared World Model + Orchestrator + Event Bus (`Scoped-Done`)
**Current state**
- Canonical world/events/play orchestration is active and in use.

**Remaining follow-up**
1. Continue reducing module-local singleton state where practical.
2. Formalize event naming/payload conventions for broader subscriber usage.
3. Expand world-first API paths where it lowers coupling.

### P2 - Procedural Rooms + Door Transitions + Room-Based Spawn (`Scoped-Done`)
**Current state**
- Core room generation, transition continuity, and safe entry spawn behavior are integrated.

**Remaining follow-up**
1. Add richer room topology/variety beyond the current sequence model.
2. Add deterministic generator assertions once room tests are in place.
3. Evaluate optional room-bound variation beyond current shared playfield envelope.

### P3 - Progression + Evacuation + Victory Sequencing (`Scoped-Done`)
**Current state**
- Functional and aligned with current design (rooms -> final room -> evacuation interaction).

**Optional follow-up**
1. Emit richer progression/evacuation events for presentation decoupling.
2. Move any remaining direct transition callsites to event/flag boundaries if desired.

### P4 - FSM and AI/Motion Separation (`Scoped-Done`)
**Current scope decision**
- Hunter remains `Idle/Chase` by design.

**Optional gap if strict FSM parity is needed**
1. Add hunter `return` state.
2. Further separate intent generation from integration for all enemy classes.

### P6 - Difficulty Scaling Integration (`Partial`)
**What is done**
- Profile-based difficulty factors are live.
- Health-scaled player impairment provides real-time pressure tied to health state.

**What is missing**
- No global adaptive in-run scaling based on elapsed time, room count, or performance telemetry.

**Implementation steps**
1. Add periodic live difficulty evaluation from runtime metrics.
2. Derive bounded multipliers for enemy pressure/spawn pacing.
3. Apply live multipliers with safety clamps to avoid abrupt spikes.

### P7 - Presentation Completion (`Partial`)
**What is missing**
- `src/systems/vfx_system.lua` is still empty.
- `src/ui/messages.lua` is still empty.
- Presentation hooks are still mostly direct-call instead of event-subscriber driven.

**Implementation steps**
1. Implement centralized VFX aggregator.
2. Implement objective/cooldown/evacuation message layer.
3. Route UI/audio/VFX triggering through event subscriptions.

### P8 - Input/Docs Consistency + Cleanup (`Partial`)
**What is missing**
- Arrow key movement aliases and `E` interact alias are not yet wired.
- README/docs controls and behavior notes need refresh for current runtime.
- Debug-only behaviors (for example always-on hitbox overlay) should be behind a toggle.

**Implementation steps**
1. Add missing input aliases.
2. Sync controls/docs with current mappings and flow.
3. Add debug flags/config for temporary instrumentation.

### P9 - Tests and Regression Harness (`Pending`)
**What is missing**
- `tests/ai_test.lua`, `tests/collision_test.lua`, and `tests/room_generation_test.lua` remain empty.

**Implementation steps**
1. Add deterministic collision tests.
2. Add AI tests for chase/reroute/unstuck transitions.
3. Add room generation tests for door continuity, safe spawn constraints, and edge-door rules.

---

## Separation of Concerns Recommendations (Current Codebase)

1. Keep `play.lua` as canonical orchestration and keep `game.lua` as compatibility facade.
2. Keep collision focused on geometry response and keep resource/damage systems effect-only.
3. Continue reusing shared helpers (`collision_system`, `math_utils`, `kinematics`, `search_utils`) to avoid drift.
4. Prefer events/flags for cross-system orchestration boundaries.
5. Keep door/evacuation behavior data-driven via context where possible.

---

## Recommended Next Execution Order

1. P6 adaptive runtime scaling beyond health-linked impairment.
2. P7 presentation systems (`vfx/messages`) and event-driven hooks.
3. P8 input aliases and docs cleanup.
4. P9 deterministic tests for room generation, AI reroute, and collisions.
5. Optional P1/P2 architecture hardening if coupling debt becomes a blocker.

This order focuses on user-visible progression and regression safety while preserving existing gameplay behavior.
