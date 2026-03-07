--[[
    Generic base class for enemies in the game.
    Features:
      - Player collision handling
      - Damage application
      - Player invulnerability timer management
      - Optional onHit callback for VFX, SFX, or other effects
--]]

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

    return self
end

-- Collision Handling
-- Applies damage to player if not currently invulnerable
-- Sets player's invulnerability timer and triggers optional onHit callback
function EnemyBase:onCollision(player)
    if not player then return end

    -- ensure numerical values
    player.health = tonumber(player.health) or 0
    player.invulTimer = tonumber(player.invulTimer) or 0
    player.hitThisFrame = player.hitThisFrame or false

    -- only apply damage if player is currently vulnerable
    if player.invulTimer <= 0 and not player.hitThisFrame then
        -- reduce health
        player.health = player.health - self.damage
        if player.health < 0 then player.health = 0 end

        -- start invulnerability
        player.invulnerable = true
        player.invulTimer = self.invulDuration or 1.0
        player.hitThisFrame = true

        -- call optional onHit callback (VFX, SFX, etc.)
        if type(self.onHit) == "function" then
            pcall(self.onHit, self, player)
        end
    end
end


-- Player Invulnerability Tick
-- Decrements the player's invulnerability timer and resets flags when expired
function EnemyBase.updatePlayerInvul(player, dt)
    if not player then return end
    local step = dt or 0

    player.damageFlickerTimer = math.max(0, (player.damageFlickerTimer or 0) - step)
    player.damageLockTimer = math.max(0, (player.damageLockTimer or 0) - step)

    player.invulTimer = (player.invulTimer or 0) - step

    if player.invulTimer <= 0 then
        -- invulnerability expired
        player.invulTimer = 0
        player.invulnerable = false
    else
        -- still invulnerable
        player.invulnerable = true
    end
end

return EnemyBase
