-- Generic enemy base with player-damage + invulnerability behavior.
-- EnemyBase.updatePlayerInvul(player, dt) decrements player's invulnerability timer

local EnemyBase = {}
EnemyBase.__index = EnemyBase

-- constructor
function EnemyBase.new(opts)
    opts = opts or {}
    local self = setmetatable({}, EnemyBase)

    self.x = opts.x or 0
    self.y = opts.y or 0
    self.width  = opts.width  or opts.size or 32
    self.height = opts.height or opts.size or 32

    -- how much damage this enemy deals to the player on contact
    self.damage = opts.damage or 10

    -- how long (seconds) the player should be invulnerable after being hit
    self.invulDuration = opts.invulDuration or 1.0

    -- called when a hit is applied
    self.onHit = opts.onHit

    -- meta flags
    self.isEnemy = true

    return self
end

--  - reduce player health
--  - set player.invulnerable = true and player.invulTimer = self.invulDuration
function EnemyBase:onCollision(player)
    if not player then return end

    player.health = tonumber(player.health) or 0
    player.invulTimer = tonumber(player.invulTimer) or 0
    player.hitThisFrame = player.hitThisFrame or false

    -- only apply damage if player is not currently invulnerable
    if player.invulTimer <= 0 and not player.hitThisFrame then
        -- apply damage
        player.health = player.health - self.damage
        if player.health < 0 then player.health = 0 end

        -- set invulnerability
        -- player.invulnerable = true
        -- player.invulTimer = self.invulDuration
        player.hitThisFrame = true

        -- optional callback (spawn VFX, play sound, etc.)
        if type(self.onHit) == "function" then
            pcall(self.onHit, self, player)
        end
    end
end

-- tick down player's invulnerability timer.
function EnemyBase.updatePlayerInvul(player, dt)
    if not player then return end
    player.invulTimer = (player.invulTimer or 0) - (dt or 0)
    if player.invulTimer <= 0 then
        player.invulTimer = 0
        player.invulnerable = false
    else
        player.invulnerable = true
    end
end

return EnemyBase
