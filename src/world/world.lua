-- Shared runtime model used by the play orchestrator and systems.
local World = {}

local function shallowCopy(tbl)
    local out = {}
    for key, value in pairs(tbl or {}) do
        out[key] = value
    end
    return out
end

function World.new(context, width, height)
    local cfg = context or {}
    local w = width or cfg.windowWidth or 1280
    local h = height or cfg.windowHeight or 720

    return {
        context = shallowCopy(cfg),
        size = {
            width = w,
            height = h
        },
        player = nil,
        entities = {
            drones = {},
            hunters = {},
            cells = {},
            powerNodes = {},
            doors = {
                entry = nil,
                exit = nil
            }
        },
        room = {
            index = 1,
            last = false,
            bounds = {
                minX = 8,
                minY = 8,
                maxX = math.max(8, w - 8),
                maxY = math.max(8, h - 8)
            }
        },
        progression = {
            roomsCleared = 0,
            roomsToEscape = 0
        },
        difficulty = {},
        metrics = {
            elapsedTime = 0,
            roomsCleared = 0,
            cellsCollected = 0
        },
        flags = {
            gameOver = false,
            victory = false,
            evacuationActive = false
        },
        events = nil
    }
end

function World.setContext(world, context)
    if not world then
        return
    end
    world.context = shallowCopy(context or {})
end

return World
