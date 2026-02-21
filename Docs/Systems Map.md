
---

## Central Orchestrator (Playing State / Game Manager)

**Role:** conductor, not a system

**Owns**

- `world` table
    
- list of active systems
    
- update & draw order
    

**Calls**

- `system:update(dt)`
    
- `system:draw()`
    
- `system:onEnter() / onExit()`
    

**Must NOT**

- contain gameplay logic
    
- change health, AI state, or difficulty directly
    

---

## WORLD DATA (shared, passive)

Think of this as **the database**, not a system.

**Contains**

- player data
    
- enemies list
    
- rooms
    
- items
    
- timers
    
- flags (evacuation started, power restored, etc.)
    

**Rule**

> Systems read/write world data - systems never reference each other.

---

# SIMULATION SYSTEMS (Logic)

These mutate the world.

---

## 1. Input System

**Owns**

- input state (pressed, held)
    

**Reads**

- keyboard / controller input
    

**Writes**

- player intent (`moveDir`, `dashRequested`)
    

**Called from**

- Playing State -> update
    

**Must NOT**

- move the player
    
- apply velocity
    
- consume energy
    

---

## 2. AI System (FSM)

**Owns**

- enemy states (idle, patrol, chase, return)
    
- state transitions
    

**Reads**

- player position
    
- enemy parameters
    
- difficulty modifiers
    

**Writes**

- enemy intent (`desiredVelocity`, `state`)
    

**Called from**

- Playing State -> update
    

**Must NOT**

- move enemies
    
- deal damage
    
- play sounds
    

---

## 3. Movement System

**Owns**

- velocity -> position integration
    

**Reads**

- entity velocity
    
- `dt`
    

**Writes**

- entity positions
    

**Called from**

- Playing State -> update
    

**Must NOT**

- check collisions
    
- clamp to walls
    
- apply knockback logic
    

---

## 4. Collision System (AABB)

**Owns**

- overlap detection
    
- collision resolution
    

**Reads**

- entity positions & hitboxes
    
- room boundaries
    
- door trigger zones
    

**Writes**

- collision flags
    
- contact events (`enemyHitPlayer`, `doorTouched`)
    
- corrected positions
    

**Called from**

- Playing State -> update (after movement)
    

**Must NOT**

- reduce health
    
- decide damage values
    
- trigger state changes directly
    

---

## 5. Damage & Invulnerability System

**Owns**

- damage rules
    
- invulnerability timers
    
- knockback vectors
    

**Reads**

- collision events
    
- entity stats
    

**Writes**

- health changes
    
- invulnerability flags
    
- knockback velocity
    

**Called from**

- Playing State -> update (after collision)
    

**Must NOT**

- detect collisions
    
- play sounds
    
- draw effects
    

---

## 6. Resource System (Health, Energy, Time)

**Owns**

- health
    
- energy
    
- regeneration
    
- survival timer
    

**Reads**

- damage events
    
- ability usage
    
- item pickups
    

**Writes**

- current resource values
    

**Called from**

- Playing State -> update
    

**Must NOT**

- render UI
    
- trigger game over directly
    

---

## 7. Ability System (Dash)

**Owns**

- dash logic
    
- cooldown timers
    
- energy cost
    

**Reads**

- input intent
    
- energy values
    

**Writes**

- player velocity changes
    
- cooldown state
    
- energy consumption
    

**Called from**

- Playing State -> update
    

**Must NOT**

- move player directly (movement system does)
    
- check collisions
    

---

## 8. Spawn System

**Owns**

- enemy spawning
    
- item spawning
    
- cleanup/despawn
    

**Reads**

- room data
    
- difficulty level
    

**Writes**

- enemies list
    
- items list
    

**Called from**

- room enter
    
- difficulty events
    

**Must NOT**

- run every frame
    
- manage AI logic
    

---

## 9. Procedural Room Generation System

**Owns**

- room layout creation
    
- door placement
    
- safe spawn points
    

**Reads**

- random seed
    
- progression flags
    

**Writes**

- room data
    
- door trigger definitions
    

**Called from**

- room transition events
    

**Must NOT**

- spawn enemies directly
    
- move player
    

---

## 10. Progression System (Power Nodes)

**Owns**

- node repair logic
    
- room unlocking rules
    

**Reads**

- item pickups
    
- room states
    

**Writes**

- progression flags
    
- unlocked paths
    

**Called from**

- interaction events
    

**Must NOT**

- trigger evacuation directly
    

---

## 11. Dynamic Difficulty System

**Owns**

- difficulty level calculation
    

**Reads**

- survival time
    
- rooms cleared
    
- progression state
    

**Writes**

- enemy modifiers
    
- spawn parameters
    

**Called from**

- Playing State -> update (low frequency)
    

**Must NOT**

- spawn enemies
    
- change AI state directly
    

---

## 12. Evacuation System

**Owns**

- evacuation timer
    
- survival condition
    

**Reads**

- progression flags
    
- player alive state
    

**Writes**

- evacuation progress
    
- victory trigger flag
    

**Called from**

- Playing State -> update (when active)
    

**Must NOT**

- change game state directly
    

---

# PRESENTATION SYSTEMS (Read-Only)

These **never change gameplay state**.

---

## 13. Animation System

**Owns**

- sprite state
    
- frame timing
    

**Reads**

- entity movement state
    
- action flags
    

**Writes**

- animation frame index
    

**Called from**

- Playing State -> update & draw
    

**Must NOT**

- modify velocity or health
    

---

## 14. UI / HUD System

**Owns**

- bars
    
- timers
    
- messages
    

**Reads**

- world resource values
    
- cooldown timers
    

**Writes**

- nothing gameplay-related
    

**Called from**

- Playing State -> draw
    

---

## 15. Audio System

**Owns**

- music playback
    
- SFX playback
    

**Reads**

- events (`playerHit`, `dashUsed`)
    

**Writes**

- audio output only
    

**Called from**

- event hooks
    

---

## 16. Visual Feedback System

**Owns**

- flicker
    
- screen flash
    
- shake
    

**Reads**

- damage events
    
- evacuation state
    

**Writes**

- visual-only state
    

**Called from**

- draw phase
    

---

# STATE SYSTEMS (Meta)

---

## Game State Manager

**Owns**

- current state
    
- transitions
    

**States**

- Menu
    
- Playing
    
- Pause
    
- Game Over
    
- Victory
    

**Rule**

> States activate systems - systems never change states directly.

---

# Architecture Summary

> “The game uses a system-oriented architecture with centralized orchestration, shared world state, decoupled simulation and presentation systems, and explicit update ordering.”

---

## Final Sanity Rule

If a system:

- **reads input AND draws UI** -> split it
    
- **moves entities AND checks collisions** -> split it
    
- **plays sound AND changes health** -> split it