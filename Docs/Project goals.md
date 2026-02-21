
## **1. Overview**

**Eclipse Protocol** is a fully playable 2D top-down survival game developed using the **Love2D framework**.  
The player controls a **maintenance robot** inside a **failing space station** where power systems are collapsing and hostile drones roam the corridors.

The project’s main goal is to **demonstrate the complete game development pipeline**, including:

- Structured code architecture
    
- Player systems
    
- Enemy AI with state machines
    
- Procedural content generation
    
- Collision detection
    
- Game state management
    
- UI, animation, and sound integration
    

This project is designed to be **portfolio-ready**, emphasizing **technical quality**, **clean architecture**, and **gameplay polish**.

---

## **2. Core Game Concept**

The space station is losing power. Systems are unstable.  
The robot must survive long enough for evacuation.

### **Player Objectives**

The player must:

- **Collect energy cells**  
    Gather scattered power units to sustain abilities and station systems.
    
- **Restore power nodes**  
    Repair damaged nodes to stabilize rooms and unlock new areas.
    
- **Avoid or disable hostile drones**  
    Navigate corridors carefully or use abilities strategically.
    
- **Survive until evacuation**  
    Manage health and energy until the evacuation sequence is completed.
    

> The station layout is **procedurally generated**, meaning **every run is different**.

---

## **3. Core Design Pillars (Required)**

This project is **not just a shooter**. It must demonstrate:

### **Gameplay Systems**

- **Resource Management**  
    Health, energy, and items must be tracked and managed.
    
- **AI Behavior**  
    Enemies must patrol, chase, and react to the player.
    
- **Dynamic Difficulty**  
    Game challenge must scale over time or progression.
    
- **Game States**  
    Full state system: menu, playing, pause, game over, victory.
    
- **Structured Architecture**  
    Modular Lua files, clean logic separation, and maintainability.
    

---

## **4. Core Gameplay Mechanics **

### **4.1 Player System**

You must implement:

- **Velocity-based movement**  
    Smooth movement using velocity and `dt` (no `x = x + 1`).
    
- **Health system**  
    Player health decreases upon damage and is visually displayed.
    
- **Energy system**  
    Energy powers abilities and must regenerate or be collected.
    
- **Dash ability with cooldown**  
    Short burst movement with a cooldown to prevent spamming.
    
- **Sprite animation**
    Use sprite sheets for movement, dash, or idle animations.
    

---

## **5. Enemy AI System**

### **5.1 Required Enemy Types**

You must implement **at least TWO enemy archetypes**.

#### **1. Patrol Drone (Predictable Threat)**

- Moves between two fixed points
    
- Ignores player position
    
- Acts as a moving obstacle
    
- Forces timing and positioning
    

#### **2. Hunter Drone (Active Threat)**

- Detects the player within a range
    
- Actively chases the player
    
- Forces movement and urgency
    

---

### **5.2 State-Based AI (FSM Required)**

Enemy behavior **must be controlled by a Finite State Machine (FSM)**.

#### **Required States**

|State|Description|
|---|---|
|Idle|Enemy is inactive or waiting|
|Patrol|Moves between predefined points|
|Chase|Moves toward the player|
|Return|Returns to original position|

> FSM logic must switch states **based on player distance or events**.

---

### **5.3 Collision & Player Safety**

You must implement:

- **AABB collision detection**
    
- **Damage on contact**
    
- **Invulnerability timer** after being hit
    
- **Knockback or flicker effect**
    

This prevents instant death from overlapping enemies.

---

## **6. Dynamic Difficulty Scaling (Required)**

Difficulty must increase **programmatically** based on:

- Time survived
    
- Rooms cleared
    
- Player progress
    

### **Examples**

- Faster enemy movement
    
- Increased spawn count
    
- Larger detection ranges
    
- Environmental hazards
    

---

## **7. Procedural Room Generation**

The station **must be generated through code**.

### **Key Requirements**

- No hardcoded maps
    
- Rooms generated randomly each run
    
- Enemies and items spawn dynamically
    
- Use `math.randomseed(os.time())`
    
- Use Lua tables to store rooms and objects
    

### **Room Transition**

- Doors act as invisible trigger zones
    
- Touching a door generates a new room
    
- Player is repositioned safely
    
- Boundaries and collisions update instantly
    

---

## **8. Progression & Unlocking Areas**

- Power nodes **must be repaired** to unlock new rooms
    
- Player cannot progress without stabilization
    
- Exploration paths differ every run
    

---

## **9. Evacuation & Victory Logic**

The evacuation is a **game state**, not just a room.

### **Evacuation Sequence**

- Triggered after repairing required nodes
    
- Becomes a survival challenge
    
- Player must survive until completion
    
- Leads to the **Victory Screen**
    

---

## **10. Collision & Physics Systems**

Required implementations:

- AABB collision for all entities
    
- Wall boundaries
    
- Ability or projectile collisions
    
- Health reduction logic
    

---

## **11. Game State System (Mandatory Architecture)**

You **must** include:

- Start Menu
    
- Playing
    
- Pause
    
- Game Over
    
- Victory Screen
    

Use a **state manager or state variable system**.

---

## **12. Resource Management System**

Player must manage:

- **Health**
    
- **Energy**
    
- **Score or survival time**
    

Energy must **regenerate or be collected**.

---

## **13. Sound & Feedback (Required)**

### **Audio**

- Background music
    
- At least **3 sound effects**
    

### **Visual Feedback**

- Flicker or screen effects on damage
    
- Clear UI indicators
    

---

## **14. UI & HUD Requirements**

Must display:

- Health bar
    
- Energy bar
    
- Score or survival time
    
- Game messages (pause, victory, cooldowns)

---

## **15. Code Architecture Requirements**

Your project **must include**:

- Multiple Lua files (minimum 4)
    
- No single 1000-line file
    
- Modular functions
    
- Proper naming conventions
    

### **Example Structure**

```
/src
  main.lua
  player.lua
  enemy.lua
  states.lua
/assets
  sprites/
  sounds/
```

---

## **16. Project Phases & Deliverables**

### **Phase 1 – Midway (30%)**

Must include:

- Player movement
    
- One enemy type
    
- Collision detection
    
- Health or score system
    
- Basic UI
    
- One sound effect
    
- Modular code
    

### **Final Phase (70%)**

Must include **everything**, plus:

- Two enemy types
    
- Energy & abilities
    
- Full game states
    
- Difficulty scaling
    
- Procedural rooms
    
- Animation
    
- Polished UI
    
- Sound system
    
- Game balance
    

---

## **17. Version Control (Mandatory)**

- GitHub repository required
    
- Regular commits
    
- Clear commit messages
    
- Organized structure
    
- README with run instructions
    


---

## **Final Note**

This project is designed to simulate **real game development practices**.  
Focus on:

- Clean architecture
    
- Fair gameplay
    
- Technical correctness
    
- Polish and creativity