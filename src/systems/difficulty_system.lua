-- Difficulty scaling: resolves selected profile and computes scaled gameplay values.
local DifficultySystem = {}

local DEFAULT_BASE = {
    abilities = {
        dashEnergyCost = 20,
        stunGunEnergyCost = 60
    },
    enemies = {
        patrolCount = 2,
        hunterCount = 1,
        patrolDamage = 12,
        hunterDamage = 15
    },
    objectives = {
        powerNodeCount = 3,
        roomsToEscape = 3,
        timeLimitSeconds = 240,
        roomClearTimeBonusSeconds = 20
    },
    resources = {
        cellCount = 10
    }
}

local DEFAULT_PROFILES = {
    {
        id = "easy",
        label = "Easy",
        description = "Lower pressure: cheaper abilities, fewer threats, fewer rooms, and a more generous evacuation timer.",
        factors = {
            abilityCost = 0.75,
            enemyDamage = 0.8,
            enemyCount = 0.8,
            nodeCount = 0.8,
            cellCount = 1.25,
            roomsToEscape = 0.7,
            timeLimit = 1.3,
            roomTimeBonus = 1.25
        }
    },
    {
        id = "medium",
        label = "Medium",
        description = "Baseline challenge.",
        factors = {
            abilityCost = 1.0,
            enemyDamage = 1.0,
            enemyCount = 1.0,
            nodeCount = 1.0,
            cellCount = 1.0,
            roomsToEscape = 1.0,
            timeLimit = 1.0,
            roomTimeBonus = 1.0
        }
    },
    {
        id = "hard",
        label = "Hard",
        description = "Higher pressure: expensive abilities, stronger enemies, longer escape run, and a tighter evacuation timer.",
        factors = {
            abilityCost = 1.35,
            enemyDamage = 1.4,
            enemyCount = 1.5,
            nodeCount = 1.4,
            cellCount = 0.8,
            roomsToEscape = 1.65,
            timeLimit = 0.75,
            roomTimeBonus = 0.8
        }
    }
}

local function round(value)
    return math.floor((value or 0) + 0.5)
end

local function scaleInt(baseValue, factor, minValue)
    local scaled = round((baseValue or 0) * (factor or 1))
    return math.max(minValue or 0, scaled)
end

local function getProfiles(context)
    local profiles = context and context.difficultyProfiles
    if type(profiles) == "table" and #profiles > 0 then
        return profiles
    end
    return DEFAULT_PROFILES
end

local function getBase(context)
    return (context and context.difficultyBase) or DEFAULT_BASE
end

function DifficultySystem.resolveSelection(context)
    local profiles = getProfiles(context)
    local index = 1

    local selectedIndex = context and context.selectedDifficultyIndex
    if type(selectedIndex) == "number" then
        index = math.max(1, math.min(#profiles, math.floor(selectedIndex)))
    end

    local selectedId = context and context.selectedDifficultyId
    if type(selectedId) == "string" then
        for i, profile in ipairs(profiles) do
            if profile.id == selectedId then
                index = i
                break
            end
        end
    end

    return profiles[index], index
end

function DifficultySystem.getOptions(context)
    return getProfiles(context)
end

function DifficultySystem.buildRuntimeValues(context)
    -- Computes effective gameplay values from base values and selected profile factors.
    local base = getBase(context)
    local profile, selectedIndex = DifficultySystem.resolveSelection(context)
    local factors = (profile and profile.factors) or {}

    local abilities = base.abilities or DEFAULT_BASE.abilities
    local enemies = base.enemies or DEFAULT_BASE.enemies
    local objectives = base.objectives or DEFAULT_BASE.objectives
    local resources = base.resources or DEFAULT_BASE.resources

    return {
        profileId = (profile and profile.id) or "easy",
        profileLabel = (profile and profile.label) or "Easy",
        selectedIndex = selectedIndex,
        dashEnergyCost = scaleInt(abilities.dashEnergyCost, factors.abilityCost, 1),
        stunGunEnergyCost = scaleInt(abilities.stunGunEnergyCost, factors.abilityCost, 1),
        patrolDamage = scaleInt(enemies.patrolDamage, factors.enemyDamage, 1),
        hunterDamage = scaleInt(enemies.hunterDamage, factors.enemyDamage, 1),
        patrolCount = scaleInt(enemies.patrolCount, factors.enemyCount, 1),
        hunterCount = scaleInt(enemies.hunterCount, factors.enemyCount, 1),
        powerNodeCount = scaleInt(objectives.powerNodeCount, factors.nodeCount, 1),
        cellCount = scaleInt(resources.cellCount, factors.cellCount, 0),
        roomsToEscape = scaleInt(objectives.roomsToEscape, factors.roomsToEscape, 1),
        timeLimitSeconds = scaleInt(objectives.timeLimitSeconds, factors.timeLimit, 30),
        roomClearTimeBonusSeconds = scaleInt(objectives.roomClearTimeBonusSeconds, factors.roomTimeBonus, 0)
    }
end

return DifficultySystem
