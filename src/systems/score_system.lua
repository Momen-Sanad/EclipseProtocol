-- Builds final run summaries and score values for result screens.
local ScoreSystem = {}

local DEFAULT_CELL_POINTS = 250
local DEFAULT_PAR_SECONDS_PER_ROOM = 90
local DEFAULT_VICTORY_TIME_BONUS_PER_SECOND = 10
local DEFAULT_FAILURE_SURVIVAL_POINTS_PER_SECOND = 5

local function clampNonNegative(value)
    return math.max(0, value or 0)
end

local function formatWithSeparators(value)
    local text = tostring(math.max(0, math.floor(value or 0)))
    local formatted = text
    while true do
        local nextText, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        formatted = nextText
        if count == 0 then
            break
        end
    end
    return formatted
end

function ScoreSystem.formatTime(seconds)
    local total = math.max(0, math.floor(seconds or 0))
    local mins = math.floor(total / 60)
    local secs = total % 60
    return string.format("%02d:%02d", mins, secs)
end

function ScoreSystem.formatScore(score)
    return formatWithSeparators(score)
end

function ScoreSystem.emptySummary(result)
    local state = result or "gameover"
    return {
        result = state,
        cellsCollected = 0,
        elapsedTime = 0,
        roomsCleared = 0,
        roomsToEscape = 0,
        cellScore = 0,
        timeScore = 0,
        completionBonus = 0,
        totalScore = 0,
        formattedTime = ScoreSystem.formatTime(0),
        formattedCells = "0",
        formattedScore = "0"
    }
end

function ScoreSystem.buildRunSummary(result, metrics, context)
    local cfg = context or {}
    local data = metrics or {}
    local state = result or "gameover"
    local elapsedTime = clampNonNegative(data.elapsedTime)
    local cellsCollected = math.max(0, math.floor(data.cellsCollected or 0))
    local roomsCleared = math.max(0, math.floor(data.roomsCleared or 0))
    local roomsToEscape = math.max(1, math.floor(data.roomsToEscape or 1))

    local cellPoints = math.max(1, math.floor(cfg.scoreCellPoints or DEFAULT_CELL_POINTS))
    local parSecondsPerRoom = math.max(15, math.floor(cfg.scoreParSecondsPerRoom or DEFAULT_PAR_SECONDS_PER_ROOM))
    local victoryTimeBonusPerSecond = math.max(
        0,
        math.floor(cfg.scoreVictoryTimeBonusPerSecond or DEFAULT_VICTORY_TIME_BONUS_PER_SECOND)
    )
    local failureSurvivalPointsPerSecond = math.max(
        0,
        math.floor(cfg.scoreFailureSurvivalPointsPerSecond or DEFAULT_FAILURE_SURVIVAL_POINTS_PER_SECOND)
    )

    local cellScore = cellsCollected * cellPoints
    local timeScore = 0

    if state == "victory" then
        local parTime = roomsToEscape * parSecondsPerRoom
        timeScore = math.max(0, math.floor((parTime - elapsedTime) * victoryTimeBonusPerSecond))
    else
        timeScore = math.floor(elapsedTime * failureSurvivalPointsPerSecond)
    end

    local totalScore = cellScore + timeScore

    return {
        result = state,
        cellsCollected = cellsCollected,
        elapsedTime = elapsedTime,
        roomsCleared = roomsCleared,
        roomsToEscape = roomsToEscape,
        cellScore = cellScore,
        timeScore = timeScore,
        completionBonus = 0,
        totalScore = totalScore,
        formattedTime = ScoreSystem.formatTime(elapsedTime),
        formattedCells = formatWithSeparators(cellsCollected),
        formattedScore = ScoreSystem.formatScore(totalScore)
    }
end

return ScoreSystem
