-- Lightweight event queue used by the play orchestrator.
local Events = {}

function Events.new()
    local queue = {}

    return {
        push = function(_, name, payload)
            if not name then
                return
            end
            queue[#queue + 1] = {
                name = name,
                payload = payload
            }
        end,
        drain = function()
            local drained = queue
            queue = {}
            return drained
        end,
        count = function()
            return #queue
        end,
        clear = function()
            queue = {}
        end
    }
end

return Events
