-- Tracks run progression state and difficulty-derived runtime config.
local DifficultySystem = require("src/systems/difficulty_system")

local ProgressionSystem = {}

local DEFAULT_ROOMS_TO_ESCAPE = 3
local DEFAULT_TIME_LIMIT_SECONDS = 240
local DEFAULT_ROOM_CLEAR_BONUS_SECONDS = 20

local activeDifficulty = nil
local roomsCleared = 0
local roomsToEscape = DEFAULT_ROOMS_TO_ESCAPE
local elapsedTime = 0
local timeLimitSeconds = DEFAULT_TIME_LIMIT_SECONDS
local timeRemainingSeconds = DEFAULT_TIME_LIMIT_SECONDS
local roomClearTimeBonusSeconds = DEFAULT_ROOM_CLEAR_BONUS_SECONDS

local function formatTime(seconds)
    local total = math.max(0, math.ceil(seconds or 0))
    local mins = math.floor(total / 60)
    local secs = total % 60
    return string.format("%02d:%02d", mins, secs)
end

function ProgressionSystem.beginRun(context)
    -- Resets progression counters from selected difficulty profile.
    activeDifficulty = DifficultySystem.buildRuntimeValues(context)
    roomsCleared = 0
    roomsToEscape = activeDifficulty.roomsToEscape or DEFAULT_ROOMS_TO_ESCAPE
    timeLimitSeconds = activeDifficulty.timeLimitSeconds or DEFAULT_TIME_LIMIT_SECONDS
    roomClearTimeBonusSeconds = activeDifficulty.roomClearTimeBonusSeconds or DEFAULT_ROOM_CLEAR_BONUS_SECONDS
    timeRemainingSeconds = timeLimitSeconds
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

function ProgressionSystem.getTimeRemaining()
    return timeRemainingSeconds
end

function ProgressionSystem.getTimeLimit()
    return timeLimitSeconds
end

function ProgressionSystem.getRoomClearTimeBonus()
    return roomClearTimeBonusSeconds
end

function ProgressionSystem.addElapsedTime(dt)
    elapsedTime = elapsedTime + (dt or 0)
end

function ProgressionSystem.tickCountdown(dt)
    local step = math.max(0, dt or 0)
    if step <= 0 then
        return timeRemainingSeconds <= 0
    end

    timeRemainingSeconds = math.max(0, timeRemainingSeconds - step)
    return timeRemainingSeconds <= 0
end

function ProgressionSystem.advanceRoom()
    -- Marks one room objective completion and reports victory threshold.
    roomsCleared = roomsCleared + 1
    timeRemainingSeconds = timeRemainingSeconds + math.max(0, roomClearTimeBonusSeconds or 0)
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
    local timerText = "TIME " .. formatTime(timeRemainingSeconds)
    return roomProgress .. "  |  DIFFICULTY " .. string.upper(diffLabel) .. "  |  " .. timerText
end

return ProgressionSystem
