-- Tracks run progression state and difficulty-derived runtime config.
local DifficultySystem = require("src/systems/difficulty_system")

local ProgressionSystem = {}

local DEFAULT_ROOMS_TO_ESCAPE = 3

local activeDifficulty = nil
local roomsCleared = 0
local roomsToEscape = DEFAULT_ROOMS_TO_ESCAPE
local elapsedTime = 0

function ProgressionSystem.beginRun(context)
    -- Resets progression counters from selected difficulty profile.
    activeDifficulty = DifficultySystem.buildRuntimeValues(context)
    roomsCleared = 0
    roomsToEscape = activeDifficulty.roomsToEscape or DEFAULT_ROOMS_TO_ESCAPE
    elapsedTime = 0
    return activeDifficulty
end

function ProgressionSystem.getDifficulty()
    return activeDifficulty
end

function ProgressionSystem.getRoomsCleared()
    return roomsCleared
end

function ProgressionSystem.getRoomsToEscape()
    return roomsToEscape
end

function ProgressionSystem.getElapsedTime()
    return elapsedTime
end

function ProgressionSystem.addElapsedTime(dt)
    elapsedTime = elapsedTime + (dt or 0)
end

function ProgressionSystem.advanceRoom()
    -- Marks one room objective completion and reports victory threshold.
    roomsCleared = roomsCleared + 1
    return roomsCleared >= roomsToEscape
end

function ProgressionSystem.buildPlayerResetConfig(context, difficulty)
    -- Applies difficulty-scaled ability costs without mutating shared global context.
    local cfg = {}
    for key, value in pairs(context or {}) do
        cfg[key] = value
    end
    if difficulty then
        cfg.playerDashEnergyCost = difficulty.dashEnergyCost
    end
    return cfg
end

function ProgressionSystem.buildAbilityConfig(context, difficulty)
    -- Ability system receives scaled stun-gun cost plus shared base tuning.
    local cfg = context or {}
    return {
        stunGunStunDuration = cfg.stunGunStunDuration,
        stunGunCooldown = cfg.stunGunCooldown,
        stunGunRange = cfg.stunGunRange,
        stunGunEnergyCost = difficulty and difficulty.stunGunEnergyCost or cfg.stunGunEnergyCost,
        stunGunLaserLifetime = cfg.stunGunLaserLifetime,
        stunGunSoundPath = cfg.stunGunSoundPath
    }
end

function ProgressionSystem.getStatusLine()
    local roomProgress = ("ROOMS STABILIZED %d/%d"):format(roomsCleared, roomsToEscape)
    local diffLabel = (activeDifficulty and activeDifficulty.profileLabel) or "Medium"
    return roomProgress .. "  |  DIFFICULTY " .. string.upper(diffLabel)
end

return ProgressionSystem
