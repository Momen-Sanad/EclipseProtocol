-- Lightweight floating-text effects used for contextual gameplay feedback.
local VfxSystem = {}

local effects = {}

local function drawOutlinedText(text, x, y, color, shadow, scale)
    local fg = color or { 1.0, 1.0, 1.0, 1.0 }
    local bg = shadow or { 0.05, 0.06, 0.08, fg[4] or 1.0 }
    local s = scale or 1.0

    love.graphics.setColor(bg)
    love.graphics.print(text, x - 1, y, 0, s, s)
    love.graphics.print(text, x + 1, y, 0, s, s)
    love.graphics.print(text, x, y - 1, 0, s, s)
    love.graphics.print(text, x, y + 1, 0, s, s)

    love.graphics.setColor(fg)
    love.graphics.print(text, x, y, 0, s, s)
end

function VfxSystem.reset()
    effects = {}
end

function VfxSystem.spawnFloatingText(text, x, y, opts)
    if not text or text == "" then
        return
    end

    local cfg = opts or {}
    effects[#effects + 1] = {
        text = tostring(text),
        x = x or 0,
        y = y or 0,
        rise = cfg.rise or 28,
        driftX = cfg.driftX or 0,
        delay = math.max(0, cfg.delay or 0),
        duration = math.max(0.05, cfg.duration or 0.7),
        wobbleAmp = cfg.wobbleAmp or 2,
        wobbleSpeed = cfg.wobbleSpeed or 8,
        phase = cfg.phase or 0,
        scale = cfg.scale or 1.0,
        elapsed = 0,
        color = cfg.color or { 1.0, 0.95, 0.9, 1.0 }
    }
end

function VfxSystem.spawnRepairFailHint(player, playerSize)
    local size = playerSize or 35
    local baseX = (player and player.x or 0) + (size * 0.5)
    local baseY = (player and player.y or 0) - 6

    VfxSystem.spawnFloatingText("STAND", baseX, baseY, {
        delay = 0.0,
        duration = 0.75,
        rise = 24,
        wobbleAmp = 2.5,
        wobbleSpeed = 10,
        phase = 0.2,
        scale = 1.25,
        color = { 1.0, 0.86, 0.78, 1.0 }
    })

    VfxSystem.spawnFloatingText("STILL", baseX, baseY - 10, {
        delay = 0.64,
        duration = 0.78,
        rise = 28,
        wobbleAmp = 2.2,
        wobbleSpeed = 9.5,
        phase = 1.1,
        scale = 1.25,
        color = { 1.0, 0.92, 0.84, 1.0 }
    })
end

function VfxSystem.update(dt)
    local step = dt or 0
    for i = #effects, 1, -1 do
        local fx = effects[i]
        fx.elapsed = fx.elapsed + step
        local liveTime = fx.elapsed - fx.delay
        if liveTime >= fx.duration then
            table.remove(effects, i)
        end
    end
end

function VfxSystem.draw()
    for _, fx in ipairs(effects) do
        local liveTime = fx.elapsed - fx.delay
        if liveTime >= 0 then
            local t = math.max(0, math.min(1, liveTime / fx.duration))
            local fade = 1 - t
            local wobble = math.sin((liveTime * fx.wobbleSpeed) + fx.phase) * fx.wobbleAmp * fade
            local scale = fx.scale or 1.0
            local textWidth = (love.graphics.getFont():getWidth(fx.text)) * scale
            local drawX = math.floor((fx.x + (fx.driftX * t) + wobble) - (textWidth * 0.5))
            local drawY = math.floor(fx.y - (fx.rise * t))
            local color = {
                fx.color[1] or 1.0,
                fx.color[2] or 1.0,
                fx.color[3] or 1.0,
                (fx.color[4] or 1.0) * fade
            }

            drawOutlinedText(fx.text, drawX, drawY, color, { 0.08, 0.08, 0.1, 0.9 * fade }, scale)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return VfxSystem
