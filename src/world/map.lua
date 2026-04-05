-- Room-sequence state for procedural run generation.
local RoomGenerator = require("src/world/room_generator")

local Map = {}

function Map.new(opts)
    local cfg = opts or {}
    local seed = cfg.seed or os.time()
    return {
        seed = seed,
        width = cfg.width or 1280,
        height = cfg.height or 720,
        index = 0,
        rooms = {},
        currentRoom = nil
    }
end

function Map.getCurrentRoom(map)
    return map and map.currentRoom or nil
end

function Map.nextRoom(map, opts)
    local cfg = opts or {}
    if not map then
        return nil
    end

    map.index = map.index + 1
    local roomSeed = (map.seed or 1) + (map.index * 7919)
    local room = RoomGenerator.generate({
        seed = roomSeed,
        index = map.index,
        width = cfg.width or map.width,
        height = cfg.height or map.height,
        entryDoor = cfg.entryDoor,
        roomsCleared = cfg.roomsCleared or 0,
        roomsToEscape = cfg.roomsToEscape or 1,
        context = cfg.context
    })

    map.rooms[map.index] = room
    map.currentRoom = room
    map.width = cfg.width or map.width
    map.height = cfg.height or map.height
    return room
end

return Map
