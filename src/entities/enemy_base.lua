--[[
    Generic base class for enemies in the game.
    Features:
      - Shared position/size defaults
      - Shared stun-flicker visual state
      - Optional onHit callback hook
]]

local EnemyBase = {}
EnemyBase.__index = EnemyBase

-- Constructor
function EnemyBase.new(opts)
    opts = opts or {}
    local self = setmetatable({}, EnemyBase)

    -- Position and size
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.width  = opts.width  or opts.size or 32
    self.height = opts.height or opts.size or 32

    -- Damage properties
    self.damage = opts.damage or 10             -- damage dealt to player on collision
    self.invulDuration = opts.invulDuration or 1.0  -- seconds of invulnerability after hit

    -- Optional callback when enemy hits the player
    self.onHit = opts.onHit

    -- Meta flags for gameplay logic
    self.isEnemy = true
    self.stunFlickerTimer = 0
    self.stunFlickerDuration = 0.3
    self.stunFlickerCount = 4

    return self
end

function EnemyBase.applyStunFlicker(enemy, duration, count)
    if not enemy then
        return
    end
    local nextDuration = math.max(0.05, duration or enemy.stunFlickerDuration or 0.3)
    enemy.stunFlickerDuration = nextDuration
    enemy.stunFlickerCount = math.max(1, math.floor(count or enemy.stunFlickerCount or 4))
    enemy.stunFlickerTimer = nextDuration
end

function EnemyBase.updateStunFlicker(enemy, dt)
    if not enemy then
        return
    end
    enemy.stunFlickerTimer = math.max(0, (enemy.stunFlickerTimer or 0) - (dt or 0))
end

function EnemyBase.getStunFlickerAlpha(enemy)
    if not enemy then
        return 1
    end

    local timer = enemy.stunFlickerTimer or 0
    if timer <= 0 then
        return 1
    end

    local duration = math.max(0.05, enemy.stunFlickerDuration or 0.3)
    local flickerCount = math.max(1, math.floor(enemy.stunFlickerCount or 4))
    local phaseCount = flickerCount * 2
    local progress = 1 - (timer / duration)
    progress = math.max(0, math.min(1, progress))
    local phase = math.floor(progress * phaseCount)
    if (phase % 2) == 1 then
        return 0.25
    end
    return 1
end

return EnemyBase
