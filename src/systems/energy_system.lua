-- Energy helpers for restoring/spending resource values with max-cap enforcement.
local EnergySystem = {}

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
    local maxEnergy = player.maxEnergy or before
    player.energy = math.min(maxEnergy, before + (count * perCell))

    return player.energy - before
end

return EnergySystem
