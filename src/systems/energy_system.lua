-- Energy helpers for restoring/spending resource values with max-cap enforcement.
local EnergySystem = {}

local function clampEnergy(player)
    if not player or type(player.energy) ~= "number" then
        return
    end

    local maxEnergy = math.max(0, player.maxEnergy or 0)
    player.energy = math.max(0, math.min(maxEnergy, player.energy))
end

function EnergySystem.restoreFromCells(player, collectedCount, energyPerCell)
    -- Applies pickup gain with clamping and returns the actual energy restored.
    if not player or type(player.energy) ~= "number" then
        return 0
    end

    local count = math.max(0, math.floor(collectedCount or 0))
    if count <= 0 then
        return 0
    end

    local perCell = math.max(0, energyPerCell or 0)
    local before = player.energy
    player.energy = before + (count * perCell)
    clampEnergy(player)

    return player.energy - before
end

function EnergySystem.canSpend(player, amount)
    -- Returns true when player has enough tracked energy for the requested cost.
    if not player then
        return false
    end
    if type(player.energy) ~= "number" then
        return true
    end
    local cost = math.max(0, amount or 0)
    return player.energy >= cost
end

function EnergySystem.spend(player, amount)
    -- Consumes energy and returns the amount actually spent.
    if not player or type(player.energy) ~= "number" then
        return 0
    end

    local cost = math.max(0, amount or 0)
    if cost <= 0 then
        return 0
    end

    local before = player.energy
    player.energy = before - cost
    clampEnergy(player)
    return before - player.energy
end

function EnergySystem.regen(player, dt, regenPerSecond)
    -- Restores energy over time and returns the amount restored this frame.
    if not player or type(player.energy) ~= "number" then
        return 0
    end

    local rate = math.max(0, regenPerSecond or 0)
    if rate <= 0 then
        return 0
    end

    local step = math.max(0, dt or 0)
    if step <= 0 then
        return 0
    end

    local before = player.energy
    player.energy = before + (rate * step)
    clampEnergy(player)
    return player.energy - before
end

function EnergySystem.update(player, dt, regenPerSecond)
    -- Frame update hook used by gameplay state to apply passive regeneration.
    return EnergySystem.regen(player, dt, regenPerSecond)
end

return EnergySystem
