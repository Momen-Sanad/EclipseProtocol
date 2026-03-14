-- Health resource rules: applies health deltas and exposes death checks.
local MathUtils = require("src/utils/math_utils")

local HealthSystem = {}

local function clampHealth(player)
    if not player then
        return
    end

    local maxHealth = math.max(0, player.maxHealth or 0)
    if player.health == nil then
        player.health = maxHealth
    end
    player.health = MathUtils.clamp(player.health, 0, maxHealth)
end

function HealthSystem.applyDelta(player, delta)
    -- Applies one signed health delta (negative for damage, positive for healing).
    if not player or type(delta) ~= "number" or delta == 0 then
        return 0
    end

    local before = player.health or 0
    player.health = before + delta
    clampHealth(player)
    return (player.health or 0) - before
end

function HealthSystem.applyRequests(player, requests)
    -- Applies a list of damage/heal requests and returns aggregate totals.
    local totalApplied = 0
    local totalDamage = 0
    local totalHealing = 0

    if not player or type(requests) ~= "table" then
        clampHealth(player)
        return {
            totalApplied = totalApplied,
            totalDamage = totalDamage,
            totalHealing = totalHealing
        }
    end

    for _, request in ipairs(requests) do
        local amount = request and tonumber(request.amount) or 0
        if amount > 0 then
            -- Positive request amount represents damage, so delta is negative.
            local applied = HealthSystem.applyDelta(player, -amount)
            totalApplied = totalApplied + applied
            totalDamage = totalDamage + math.abs(applied)
        elseif amount < 0 then
            -- Negative request amount represents healing.
            local applied = HealthSystem.applyDelta(player, -amount)
            totalApplied = totalApplied + applied
            totalHealing = totalHealing + math.max(0, applied)
        end
    end

    return {
        totalApplied = totalApplied,
        totalDamage = totalDamage,
        totalHealing = totalHealing
    }
end

function HealthSystem.isDead(player)
    if not player then
        return false
    end
    return (player.health or 0) <= 0
end

function HealthSystem.ensureValid(player)
    clampHealth(player)
end

return HealthSystem
