-- Difficulty scaling: resolves selected profile and computes scaled gameplay values.
local DifficultySystem = {}

local DEFAULT_BASE = {
    abilities = {
        dashEnergyCost = 20,
        stunGunEnergyCost = 60,
        stunGunCostRoundStep = 5
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
        roomTimeBudgetSeconds = 30,
        roomClearTimeBonusSeconds = 5
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
            roomTimeBudget = 1.35,
            roomTimeBonus = 1.35
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
            roomTimeBudget = 1.15,
            roomTimeBonus = 1.15
        }
    },
    {
        id = "hard",
        label = "Hard",
        description = "Higher pressure: expensive abilities, stronger enemies, longer escape run, and tighter timing pressure.",
        factors = {
            abilityCost = 1.35,
            enemyDamage = 1.4,
            enemyCount = 1.5,
            nodeCount = 1.4,
            cellCount = 0.8,
            roomsToEscape = 1.65,
            roomTimeBudget = 1.0,
            roomTimeBonus = 1.0
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

local function roundToNearestStep(value, step, minValue)
    local stepValue = math.max(1, math.floor(step or 1))
    if stepValue <= 1 then
        return math.max(minValue or 0, round(value or 0))
    end

    local rounded = round((value or 0) / stepValue) * stepValue
    return math.max(minValue or 0, rounded)
end

local function getProfiles(context)
    local customProfiles = context and context.difficultyProfiles
    if type(customProfiles) == "table" and #customProfiles > 0 then
        local defaultsById = {}
        for _, profile in ipairs(DEFAULT_PROFILES) do
            defaultsById[profile.id] = profile
        end

        local merged = {}
        for i, profile in ipairs(customProfiles) do
            local defaultProfile = defaultsById[profile.id] or {}
            local defaultFactors = (defaultProfile and defaultProfile.factors) or {}
            local customFactors = profile and profile.factors or {}
            local factors = {}
            for key, value in pairs(defaultFactors) do
                factors[key] = value
            end
            for key, value in pairs(customFactors) do
                factors[key] = value
            end

            merged[i] = {
                id = (profile and profile.id) or (defaultProfile and defaultProfile.id) or ("profile_" .. tostring(i)),
                label = (profile and profile.label) or (defaultProfile and defaultProfile.label) or ("Profile " .. tostring(i)),
                description = (profile and profile.description) or (defaultProfile and defaultProfile.description),
                factors = factors
            }
        end
        return merged
    end
    return DEFAULT_PROFILES
end

local function getBase(context)
    local customBase = (context and context.difficultyBase) or {}
    local merged = {
        abilities = {},
        enemies = {},
        objectives = {},
        resources = {}
    }

    local categories = { "abilities", "enemies", "objectives", "resources" }
    for _, category in ipairs(categories) do
        local defaults = DEFAULT_BASE[category] or {}
        local custom = customBase[category] or {}
        for key, value in pairs(defaults) do
            merged[category][key] = value
        end
        for key, value in pairs(custom) do
            merged[category][key] = value
        end
    end

    -- Backward compatibility: if only total time was provided in custom config, convert to per-room budget.
    local customObjectives = customBase.objectives or {}
    if customObjectives.roomTimeBudgetSeconds == nil and customObjectives.timeLimitSeconds ~= nil then
        local rooms = math.max(1, merged.objectives.roomsToEscape or DEFAULT_BASE.objectives.roomsToEscape or 1)
        merged.objectives.roomTimeBudgetSeconds = math.max(1, round((customObjectives.timeLimitSeconds or 0) / rooms))
    end

    return merged
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
    local roomsToEscape = scaleInt(objectives.roomsToEscape, factors.roomsToEscape, 1)
    local roomTimeBudgetSeconds = scaleInt(
        objectives.roomTimeBudgetSeconds,
        factors.roomTimeBudget or factors.timeLimit,
        1
    )
    local roomClearTimeBonusSeconds = scaleInt(
        objectives.roomClearTimeBonusSeconds,
        factors.roomTimeBonus,
        0
    )
    local timeLimitSeconds = roomTimeBudgetSeconds * roomsToEscape

    local stunGunEnergyCost = scaleInt(abilities.stunGunEnergyCost, factors.abilityCost, 1)
    stunGunEnergyCost = roundToNearestStep(stunGunEnergyCost, abilities.stunGunCostRoundStep, 1)

    return {
        profileId = (profile and profile.id) or "easy",
        profileLabel = (profile and profile.label) or "Easy",
        selectedIndex = selectedIndex,
        dashEnergyCost = scaleInt(abilities.dashEnergyCost, factors.abilityCost, 1),
        stunGunEnergyCost = stunGunEnergyCost,
        patrolDamage = scaleInt(enemies.patrolDamage, factors.enemyDamage, 1),
        hunterDamage = scaleInt(enemies.hunterDamage, factors.enemyDamage, 1),
        patrolCount = scaleInt(enemies.patrolCount, factors.enemyCount, 1),
        hunterCount = scaleInt(enemies.hunterCount, factors.enemyCount, 1),
        powerNodeCount = scaleInt(objectives.powerNodeCount, factors.nodeCount, 1),
        cellCount = scaleInt(resources.cellCount, factors.cellCount, 0),
        roomsToEscape = roomsToEscape,
        roomTimeBudgetSeconds = roomTimeBudgetSeconds,
        timeLimitSeconds = timeLimitSeconds,
        roomClearTimeBonusSeconds = roomClearTimeBonusSeconds
    }
end

return DifficultySystem
