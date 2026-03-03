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
    player.invulnerable = player.invulnerable or false
    player.invulTimer = tonumber(player.invulTimer) or 0

    -- only apply damage if player is not currently invulnerable
    if not player.invulnerable or player.invulTimer <= 0 then
        -- apply damage
        player.health = player.health - self.damage
        if player.health < 0 then player.health = 0 end

        -- set invulnerability
        player.invulnerable = true
        player.invulTimer = self.invulDuration

        -- optional callback (spawn VFX, play sound, etc.)
        if type(self.onHit) == "function" then
            pcall(self.onHit, self, player)
        end
    end
end

-- Helper: tick down player's invulnerability timer.
-- Call this once per frame from your main update (e.g. in states/game.lua).
-- Example: EnemyBase.updatePlayerInvul(Player, dt)
function EnemyBase.updatePlayerInvul(player, dt)
    if not player then return end
    if player.invulnerable then
        player.invulTimer = (player.invulTimer or 0) - (dt or 0)
        if player.invulTimer <= 0 then
            player.invulTimer = 0
            player.invulnerable = false
        end
    end
end

return EnemyBase