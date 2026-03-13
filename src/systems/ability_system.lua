-- Stun-gun ability: fires a short-lived laser that stuns one enemy on hit.
local AudioSystem = require("src/systems/audio_system")
local EnergySystem = require("src/systems/energy_system")
local EnemyBase = require("src/entities/enemy_base")
local Kinematics = require("src/utils/kinematics")

local AbilitySystem = {}

local STUN_DURATION_DEFAULT = 5.0
local COOLDOWN_DEFAULT = 20.0
local RANGE_DEFAULT = 520
local ENERGY_COST_DEFAULT = 60
local LASER_LIFETIME_DEFAULT = 0.12
local LASER_SOUND_PATH_DEFAULT = "assets/audio/sfx/Laser.mp3"

local stunDuration = STUN_DURATION_DEFAULT
local cooldown = COOLDOWN_DEFAULT
local range = RANGE_DEFAULT
local energyCost = ENERGY_COST_DEFAULT
local laserLifetime = LASER_LIFETIME_DEFAULT
local laserSoundPath = LASER_SOUND_PATH_DEFAULT
local cooldownTimer = 0
local laserTimer = 0
local beamStartX = 0
local beamStartY = 0
local beamEndX = 0
local beamEndY = 0

local function updateDashTimers(player, dt)
    -- Dash timers are ability-owned: movement only consumes the current dash state.
    if player.dashCooldownTimer and player.dashCooldownTimer > 0 then
        player.dashCooldownTimer = math.max(0, player.dashCooldownTimer - dt)
    end

    if player.isDashing then
        player.dashTimer = (player.dashTimer or 0) - dt
        if player.dashTimer <= 0 then
            player.isDashing = false
            player.dashTimer = 0
        end
    end
end

local function getDashDirection(player, input)
    -- Prefer current movement intent; fallback to the last movement direction.
    local dirX, dirY = 0, 0
    if input and input.getMoveDir then
        dirX, dirY = input.getMoveDir()
    end

    if dirX ~= 0 or dirY ~= 0 then
        player.lastMoveX = dirX
        player.lastMoveY = dirY
        return Kinematics.normalize(dirX, dirY)
    end

    local lastX = player.lastMoveX or 0
    local lastY = player.lastMoveY or 0
    if lastX == 0 and lastY == 0 then
        return 0, 0, 0
    end
    return Kinematics.normalize(lastX, lastY)
end

local function tryActivateDash(player, input)
    -- Consumes energy and starts dash when input and cooldown rules allow it.
    local dashPressed = input and input.dashPressed and input.dashPressed() or false
    if not dashPressed then
        return false
    end
    if player.isDashing then
        return false
    end
    if (player.dashCooldownTimer or 0) > 0 then
        return false
    end

    local dashEnergyCost = math.max(0, player.dashEnergyCost or 0)
    if not EnergySystem.canSpend(player, dashEnergyCost) then
        return false
    end

    local dirX, dirY, dirLen = getDashDirection(player, input)
    if dirLen == 0 then
        return false
    end

    EnergySystem.spend(player, dashEnergyCost)
    player.isDashing = true
    player.dashTimer = player.dashDuration or 0.18
    player.dashDirX = dirX
    player.dashDirY = dirY
    player.dashCooldownTimer = player.dashCooldown or 0.35
    AudioSystem.playSfx(player.dashSoundPath or "assets/audio/sfx/Dash.mp3")
    return true
end

local function getAimDir(player)
    -- Aim follows current movement; if idle, fallback to last movement direction.
    local dx = player.moveX or 0
    local dy = player.moveY or 0
    if dx == 0 and dy == 0 then
        dx = player.lastMoveX or 0
        dy = player.lastMoveY or 0
    end
    if dx == 0 and dy == 0 then
        return 1, 0
    end
    local len = math.sqrt((dx * dx) + (dy * dy))
    if len <= 0 then
        return 1, 0
    end
    return dx / len, dy / len
end

local function rayAabbHitDistance(originX, originY, dirX, dirY, minX, minY, maxX, maxY, maxDistance)
    -- Slab-based ray-vs-AABB test returning first hit distance along ray.
    local tMin = 0
    local tMax = maxDistance

    if dirX ~= 0 then
        local tx1 = (minX - originX) / dirX
        local tx2 = (maxX - originX) / dirX
        local txMin = math.min(tx1, tx2)
        local txMax = math.max(tx1, tx2)
        tMin = math.max(tMin, txMin)
        tMax = math.min(tMax, txMax)
    elseif originX < minX or originX > maxX then
        return nil
    end

    if dirY ~= 0 then
        local ty1 = (minY - originY) / dirY
        local ty2 = (maxY - originY) / dirY
        local tyMin = math.min(ty1, ty2)
        local tyMax = math.max(ty1, ty2)
        tMin = math.max(tMin, tyMin)
        tMax = math.min(tMax, tyMax)
    elseif originY < minY or originY > maxY then
        return nil
    end

    if tMax < tMin then
        return nil
    end
    if tMax < 0 then
        return nil
    end
    if tMin > maxDistance then
        return nil
    end

    return math.max(0, tMin)
end

local function findFirstEnemyHit(startX, startY, dirX, dirY, maxDistance, drones, hunters)
    -- Picks nearest hit enemy across both enemy pools.
    local bestEnemy = nil
    local bestDist = maxDistance

    local function testEnemy(enemy)
        -- Enemy hitbox is treated as its axis-aligned width/height rectangle.
        local minX = enemy.x or 0
        local minY = enemy.y or 0
        local maxX = minX + (enemy.width or 0)
        local maxY = minY + (enemy.height or 0)
        local hitDist = rayAabbHitDistance(startX, startY, dirX, dirY, minX, minY, maxX, maxY, maxDistance)
        if hitDist and hitDist <= bestDist then
            bestDist = hitDist
            bestEnemy = enemy
        end
    end

    if drones then
        for _, enemy in ipairs(drones) do
            testEnemy(enemy)
        end
    end
    if hunters then
        for _, enemy in ipairs(hunters) do
            testEnemy(enemy)
        end
    end

    return bestEnemy, bestDist
end

function AbilitySystem.reset(context)
    -- Loads per-run tuning from context and clears cooldown/laser timers.
    local cfg = context or {}
    stunDuration = cfg.stunGunStunDuration or STUN_DURATION_DEFAULT
    cooldown = cfg.stunGunCooldown or COOLDOWN_DEFAULT
    range = cfg.stunGunRange or RANGE_DEFAULT
    energyCost = cfg.stunGunEnergyCost or ENERGY_COST_DEFAULT
    laserLifetime = cfg.stunGunLaserLifetime or LASER_LIFETIME_DEFAULT
    laserSoundPath = cfg.stunGunSoundPath or LASER_SOUND_PATH_DEFAULT
    cooldownTimer = 0
    laserTimer = 0
end

function AbilitySystem.update(player, drones, hunters, input, dt, playerSize)
    -- Consumes input, validates cooldown/energy, fires beam, and stuns one enemy on hit.
    dt = dt or 0
    if cooldownTimer > 0 then
        cooldownTimer = math.max(0, cooldownTimer - dt)
    end
    if laserTimer > 0 then
        laserTimer = math.max(0, laserTimer - dt)
    end

    if not player then
        return false
    end

    updateDashTimers(player, dt)
    local dashTriggered = tryActivateDash(player, input)

    player.stunGunEnergyCost = energyCost
    player.stunGunCooldown = cooldown
    player.stunGunCooldownTimer = cooldownTimer

    local pressed = input and input.stunGunPressed and input.stunGunPressed() or false
    if not pressed then
        return dashTriggered
    end
    if cooldownTimer > 0 then
        return dashTriggered
    end
    if not EnergySystem.canSpend(player, energyCost) then
        return dashTriggered
    end

    local size = playerSize or 35
    local startX = (player.x or 0) + (size / 2)
    local startY = (player.y or 0) + (size / 2)
    local dirX, dirY = getAimDir(player)
    local hitEnemy, hitDist = findFirstEnemyHit(startX, startY, dirX, dirY, range, drones, hunters)

    -- Beam endpoint is either the first enemy hit or max range.
    beamStartX = startX
    beamStartY = startY
    beamEndX = startX + (dirX * hitDist)
    beamEndY = startY + (dirY * hitDist)
    laserTimer = laserLifetime
    AudioSystem.playSfx(laserSoundPath)

    if hitEnemy then
        -- Stun effect freezes pursuit and applies a brief flicker feedback.
        hitEnemy.pauseTimer = math.max(hitEnemy.pauseTimer or 0, stunDuration)
        hitEnemy.chasing = false
        hitEnemy.vx = 0
        hitEnemy.vy = 0
        EnemyBase.applyStunFlicker(hitEnemy, 0.35, 5)
    end

    EnergySystem.spend(player, energyCost)
    cooldownTimer = cooldown
    player.stunGunCooldownTimer = cooldownTimer

    return dashTriggered or (hitEnemy ~= nil)
end

function AbilitySystem.draw()
    -- Draw a short-lived two-pass laser (soft glow + bright core).
    if laserTimer <= 0 then
        return
    end

    local t = 0
    if laserLifetime > 0 then
        t = laserTimer / laserLifetime
    end
    t = math.max(0, math.min(1, t))

    love.graphics.setLineWidth(10)
    love.graphics.setColor(1.0, 0.95, 0.2, 0.18 * t)
    love.graphics.line(beamStartX, beamStartY, beamEndX, beamEndY)

    love.graphics.setLineWidth(4)
    love.graphics.setColor(1.0, 0.95, 0.35, 0.95 * t)
    love.graphics.line(beamStartX, beamStartY, beamEndX, beamEndY)

    love.graphics.setLineWidth(1)
end

return AbilitySystem
