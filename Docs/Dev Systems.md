# Extracted systems (ranked by priority)

---

1. **Code Architecture & Project Structure** - _foundation for everything_
    
    - Purpose: modular Lua files, folder layout, build/run scripts, git repo.
        
    - Phase: Phase 1 (required) -> Final (remains mandatory)
        
    - Prerequisite: **None**
        
2. **Game State System (state manager: Menu / Playing / Pause / Game Over / Victory)**
    
    - Purpose: manage high-level flow and screens.
        
    - Phase: Phase 1 (required)
        
    - Prerequisite: Code Architecture & Project Structure
        
3. **Input & Player Movement System (velocity + `dt`)**
    
    - Purpose: read input and move player with velocity based physics (dash support).
        
    - Phase: Phase 1 (required)
        
    - Prerequisite: Code Architecture & Project Structure, Game State System
        
4. **Collision & Physics System (AABB, walls, boundaries)**
    
    - Purpose: detect collisions between entities, walls, doors, projectiles.
        
    - Phase: Phase 1 (required)
        
    - Prerequisite: Code Architecture & Project Structure
        
5. **Player Resource Management (health, energy, score/time tracking)**
    
    - Purpose: track health, energy, survival time/score and expose APIs for UI and game logic.
        
    - Phase: Phase 1 (health/score) -> Final (full energy/regen/item integration)
        
    - Prerequisite: Player Movement System, Collision & Physics System
        
6. **Damage & Hit Response System (damage on contact, invulnerability timer, knockback/flicker)**
    
    - Purpose: apply damage, start invulnerability, visual feedback, knockback physics.
        
    - Phase: Phase 1 (basic) -> Final (polish & effects)
        
    - Prerequisite: Collision & Physics System, Player Resource Management
        
7. **Basic UI / HUD System (health bar, energy bar, score/time, messages)**
    
    - Purpose: display health/energy, survival time, cooldowns, pause/victory messages.
        
    - Phase: Phase 1 (basic) -> Final (polished)
        
    - Prerequisite: Game State System, Player Resource Management
        
8. **Single-Enemy Implementation (Patrol Drone)**
    
    - Purpose: one predictable enemy type that patrols between points (Phase 1 requirement).
        
    - Phase: Phase 1 (required)
        
    - Prerequisite: Collision & Physics System, Code Architecture, Basic Enemy framework (FSM infra)
        
9. **Enemy AI Framework: Finite State Machine (FSM)**
    
    - Purpose: provide state-based behavior engine for enemies (idle, patrol, chase, return).
        
    - Phase: Phase 1 (FSM basics) -> Final (full use by multiple archetypes)
        
    - Prerequisite: Code Architecture & Project Structure
        
10. **Hunter Drone (Active Threat with detection + chase)**
    
    - Purpose: second required enemy archetype - detects and chases player.
        
    - Phase: Final (required for final deliverable; may be in Phase 1 as extension)
        
    - Prerequisite: Enemy AI Framework (FSM), Collision & Physics System
        
11. **Enemy/Entity Spawn & Management System**
    
    - Purpose: spawn enemies, track active entities, pooling or lifecycle (spawn/despawn).
        
    - Phase: Phase 1 (basic spawner) -> Final (dynamic spawns)
        
    - Prerequisite: Procedural Room Generation (for placement), Code Architecture
        
12. **Procedural Room Generation System**
    
    - Purpose: generate rooms and layouts programmatically, no hardcoded maps.
        
    - Phase: Final (core requirement)
        
    - Prerequisite: Code Architecture & Project Structure, Random/seeding utilities
        
13. **Room Transition & Safe Repositioning System (doors as triggers)**
    
    - Purpose: detect door triggers, generate/load new rooms, reposition player safely, update collisions.
        
    - Phase: Final
        
    - Prerequisite: Procedural Room Generation, Collision & Physics System, Spawn & Management
        
14. **Item & Pickup System (energy cells, power node items)**
    
    - Purpose: items spawn/collect logic (energy cells that restore energy / fuel abilities).
        
    - Phase: Final (partial in Phase 1 if required)
        
    - Prerequisite: Spawn & Management System, Collision & Physics System, Player Resource Management
        
15. **Power Node & Progression System (repair nodes to unlock areas)**
    
    - Purpose: repair mechanics, progression gating, unlock new rooms/paths when nodes are stabilized.
        
    - Phase: Final
        
    - Prerequisite: Item & Pickup System (repair items), Procedural Room Generation, Room Transition
        
16. **Evacuation & Victory Logic**
    
    - Purpose: trigger evacuation sequence once required nodes repaired; survival timer; transition to Victory state.
        
    - Phase: Final
        
    - Prerequisite: Power Node & Progression System, Game State System
        
17. **Dynamic Difficulty Scaling System**
    
    - Purpose: adjust spawn rates, enemy speed/detection range, hazards based on time/rooms cleared/progress.
        
    - Phase: Final (required)
        
    - Prerequisite: Spawn & Management System, Metrics provider (time survived, rooms cleared)
        
18. **Abilities & Cooldown System (Dash with cooldown + any future abilities/projectiles)**
    
    - Purpose: implement dash (short burst + cooldown), manage ability states and UI cooldown feedback.
        
    - Phase: Phase 1 (dash required) -> Final (more abilities)
        
    - Prerequisite: Player Movement System, Player Resource Management, Collision & Physics System
        
19. **Projectile / Ability Collision Handling (if abilities that hit exist)**
    
    - Purpose: collisions specific to abilities/projectiles, damage application, lifespan.
        
    - Phase: Final (if projectiles are added)
        
    - Prerequisite: Collision & Physics System, Abilities System
        
20. **Animation System (sprite sheets, player & enemy animations)**
    
    - Purpose: sprite sheet handling, animation states for movement/dash/idle/hit.
        
    - Phase: Phase 1 (basic) -> Final (polished)
        
    - Prerequisite: Player Movement System, Enemy Systems
        
21. **Sound & Audio System (background music + ≥3 SFX)**
    
    - Purpose: music, SFX, audio management (volume, play on events).
        
    - Phase: Phase 1 (one SFX required) -> Final (full system)
        
    - Prerequisite: Game State System, Code Architecture (event hooks)
        
22. **Visual Feedback / Effects System (flicker, screen effects on damage)**
    
    - Purpose: damage flicker, screen shake or overlays to convey hit/evacuation, polish.
        
    - Phase: Final (basic in Phase 1 acceptable)
        
    - Prerequisite: Damage & Hit Response System, Animation System
        
23. **HUD / Message & Notification System (pause, victory, cooldown messages)**
    
    - Purpose: non-HUD game messages and overlays (cooldown prompts, objectives).
        
    - Phase: Phase 1 (basic) -> Final (polished)
        
    - Prerequisite: UI/HUD System, Game State System
        
24. **Game Metrics & Scoring System (time alive, rooms cleared, score)**
    
    - Purpose: measure survival time, rooms cleared, expose to UI and difficulty scaling.
        
    - Phase: Phase 1 (basic time/score) -> Final (rich metrics)
        
    - Prerequisite: Game State System, Spawn & Management, Procedural Room Generation
        
25. **Testing & Debug Tools (debug overlays, logging, spawn cheats)**
    
    - Purpose: visible hitboxes, stat readouts, seed replay, unit tests where possible.
        
    - Phase: Phase 1 (developer tools) -> Final (polish)
        
    - Prerequisite: Code Architecture & Project Structure
        
26. **Game Balance & Tuning System (parameter files / config)**
    
    - Purpose: central place for enemy speeds, cooldowns, spawn rates for iterative tuning.
        
    - Phase: Final (ongoing)
        
    - Prerequisite: Code Architecture, Enemy & Spawn Systems
        
27. **Build, README & Version Control Workflow**
    
    - Purpose: GitHub repo, run instructions, commit discipline, release instructions.
        
    - Phase: Phase 1 (required) -> Final
        
    - Prerequisite: Code Architecture & Project Structure
        

---

## Quick mapping: Phase 1 must-have (minimum deliverable)

- Code Architecture & Project Structure
    
- Game State System
    
- Player Movement (velocity/dt)
    
- Collision & Physics (AABB)
    
- Player Health or Score system
    
- Basic UI / HUD
    
- ONE enemy type (Patrol Drone)
    
- Basic Spawn/Entity management (for that enemy)
    
- One sound effect
    
- Modular code (≥4 Lua files)
    
- Testing/debug basics and GitHub + README
    

(These align with the doc’s **Phase 1 – Midway (30%)** requirements.)

---

## Notes & suggested implementation order (practical)

1. **Architecture & git** (foundation)
    
2. **Game State System** + minimal menu to bootstrap play mode
    
3. **Input + Player Movement** (velocity)
    
4. **Collision & Physics** (AABB collisions)
    
5. **Player Resource Management (health)** + basic HUD
    
6. **Simple enemy (Patrol) + FSM infra**
    
7. **Damage & Invulnerability** + visual hit feedback
    
8. **Spawner + one SFX** (Phase1 complete)
    
9. Then: **Procedural Generation**, **Room Transitions**, **Item/pickups**, **Hunter AI**, **Difficulty scaling**, **Evacuation**, **Polish (audio/animation/effects)**
    
---

```
[ROOT] Code Architecture & Project Structure
    ├─ file layout
    ├─ module boundaries
    └─ shared utilities



[ROOT] Version Control & README
    └─ GitHub repo, commits, run instructions




## 2. Core Control & Flow


Game State System
    → Code Architecture & Project Structure



Input System
    → Game State System




## 3. Physics & World Rules


Collision & Physics System (AABB, walls, bounds)
    → Code Architecture & Project Structure



Entity Base System (position, velocity, update/draw)
    → Collision & Physics System




## 4. Player Systems (vertical slice begins)


Player Movement System (velocity + dt)
    → Input System
    → Entity Base System



Player Resource System (health, energy, score/time)
    → Player Movement System



Damage & Invulnerability System
    → Collision & Physics System
    → Player Resource System



Abilities & Cooldown System (Dash)
    → Player Movement System
    → Player Resource System




## 5. UI & Feedback (early but layered)


Basic HUD System (health, energy, time)
    → Player Resource System
    → Game State System



Game Messages & Overlays (pause, cooldowns, victory text)
    → HUD System
    → Game State System



Visual Feedback System (flicker, knockback effects)
    → Damage & Invulnerability System




## 6. Enemy Framework (AI foundation)


Enemy Base System (shared enemy logic)
    → Entity Base System



Finite State Machine (FSM) System
    → Enemy Base System


---

## 7. Enemy Implementations


Patrol Drone (Enemy Type 1)
    → FSM System
    → Collision & Physics System



Hunter Drone (Enemy Type 2)
    → FSM System
    → Player Position Tracking
    → Collision & Physics System


---

## 8. Spawning & Runtime Management


Entity / Enemy Spawn System
    → Enemy Base System
    → Collision & Physics System



Game Metrics System (time survived, rooms cleared)
    → Game State System


---

## 9. Procedural World Systems


Procedural Room Generation
    → Code Architecture & Project Structure



Room Transition System (doors, triggers)
    → Procedural Room Generation
    → Collision & Physics System



Room-based Enemy & Item Spawning
    → Procedural Room Generation
    → Spawn System


---

## 10. Items & Progression


Item & Pickup System (energy cells)
    → Collision & Physics System
    → Player Resource System



Power Node System (repair & unlock)
    → Item & Pickup System
    → Procedural Room Generation


---

## 11. Difficulty & Scaling


Dynamic Difficulty Scaling
    → Game Metrics System
    → Spawn System
    → Enemy Systems


---

## 12. Endgame Logic


Evacuation Trigger System
    → Power Node System
    → Game Metrics System



Evacuation Survival Sequence
    → Evacuation Trigger System
    → Dynamic Difficulty Scaling



Victory State
    → Evacuation Survival Sequence
    → Game State System


---

## 13. Audio & Presentation


Audio System (music + SFX)
    → Game State System



Animation System (player & enemies)
    → Player Movement System
    → Enemy Systems


---

## 14. Polish & Dev Support


Debug & Testing Tools
    → Collision & Physics System



Balance & Tuning Config
    → Enemy Systems
    → Difficulty Scaling

```

---
