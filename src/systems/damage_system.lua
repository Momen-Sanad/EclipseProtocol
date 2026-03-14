-- Damage and invulnerability rules extracted from collision detection.
local AudioSystem = require("src/systems/audio_system")
local Kinematics = require("src/utils/kinematics")

local DamageSystem = {}

function DamageSystem.updatePlayerInvulnerability(player, dt)
    if not player then
        return
    end

    local step = dt or 0
    player.damageFlickerTimer = math.max(0, (player.damageFlickerTimer or 0) - step)
    player.damageLockTimer = math.max(0, (player.damageLockTimer or 0) - step)
    player.invulTimer = (player.invulTimer or 0) - step

    if player.invulTimer <= 0 then
        player.invulTimer = 0
        player.invulnerable = false
    else
        player.invulnerable = true
    end
end

function DamageSystem.buildPlayerDamageRequest(player, enemy, playerSize)
    -- Builds one health-delta request and applies hit-reaction state (invul/knockback/flicker).
    if not player or not enemy then
        return nil
    end

    if enemy.isStunned or (enemy.stunTimer or 0) > 0 then
        return nil
    end

    if (player.invulTimer or 0) > 0 then
        return nil
    end

    local reactionDuration = math.max(0.01, player.damageFlickerDuration or 0.4)
    local hitInvulDuration = enemy.invulDuration or 1.0

    AudioSystem.playSfx(player.damageSoundPath or "assets/audio/sfx/Damage.mp3")

    if type(enemy.onHit) == "function" then
        pcall(enemy.onHit, enemy, player)
    end

    local size = playerSize or 35
    local px = player.x or 0
    local py = player.y or 0
    local ex = enemy.x or 0
    local ey = enemy.y or 0
    local ew = enemy.width or 0
    local eh = enemy.height or 0
    local cx = px + (size / 2)
    local cy = py + (size / 2)
    local exCenter = ex + (ew / 2)
    local eyCenter = ey + (eh / 2)

    local dx = cx - exCenter
    local dy = cy - eyCenter
    local len = 0
    dx, dy, len = Kinematics.normalize(dx, dy)
    if len == 0 then
        dx, dy = 0, -1
    end

    local knockback = enemy.knockback or 300
    local immediate = enemy.immediateKnockback or 8
    Kinematics.addImpulse(player, dx * knockback, dy * knockback)
    Kinematics.composeVelocity(player)
    Kinematics.translate(player, dx * immediate, dy * immediate)

    player.damageFlickerTimer = math.max(player.damageFlickerTimer or 0, reactionDuration)
    player.damageLockTimer = math.max(player.damageLockTimer or 0, reactionDuration)
    player.invulTimer = math.max(player.invulTimer or 0, hitInvulDuration, reactionDuration)
    player.invulnerable = true
    player.hitThisFrame = true

    return {
        type = "health_delta",
        target = "player",
        amount = math.max(0, enemy.damage or 0),
        source = enemy
    }
end

function DamageSystem.processPlayerEnemyContacts(player, hitEvents, playerSize)
    -- Converts collision events into health requests while applying one hit reaction window.
    local requests = {}
    if not player or type(hitEvents) ~= "table" then
        return requests
    end

    for _, hitEvent in ipairs(hitEvents) do
        local enemy = hitEvent and hitEvent.enemy
        if enemy then
            local request = DamageSystem.buildPlayerDamageRequest(player, enemy, playerSize)
            if request then
                requests[#requests + 1] = request
            end
        end
    end

    return requests
end

function DamageSystem.applyPlayerEnemyHit(player, enemy, playerSize)
    -- Backward-compatible helper for older call sites.
    return DamageSystem.buildPlayerDamageRequest(player, enemy, playerSize) ~= nil
end

return DamageSystem
