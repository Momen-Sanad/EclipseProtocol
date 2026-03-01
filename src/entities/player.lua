local SpriteSheet = require("src/utils/sprite_sheet")

local Player = {}

function Player.new(config)
    local cfg = config or {}
    local sheet = SpriteSheet.buildFrames(cfg.spritePath or "assets/sprites/player/Robot.png")
    local frames = sheet.frames

    local maxW = 0
    local maxH = 0
    for _, frame in ipairs(frames) do
        if frame.w > maxW then
            maxW = frame.w
        end
        if frame.h > maxH then
            maxH = frame.h
        end
    end

    local baseSize = math.max(1, math.max(maxW, maxH))
    local size = cfg.size or 35
    local scale = size / baseSize

    return {
        x = cfg.x or 0,
        y = cfg.y or 0,
        speed = cfg.speed or 300,
        sprite = sheet.image,
        frames = frames,
        frameIndex = 1,
        frameTimer = 0,
        frameDuration = cfg.frameDuration or 0.12,
        scale = scale
    }
end

function Player.update(player, dt)
    if not player or not player.frames or #player.frames <= 1 then
        return
    end

    player.frameTimer = player.frameTimer + dt
    if player.frameTimer >= player.frameDuration then
        player.frameTimer = player.frameTimer - player.frameDuration
        player.frameIndex = (player.frameIndex % #player.frames) + 1
    end
end

function Player.draw(player)
    if not player then
        return
    end

    love.graphics.setColor(1, 1, 1)
    local frame = player.frames and player.frames[player.frameIndex]
    if frame then
        love.graphics.draw(
            player.sprite,
            frame.quad,
            player.x,
            player.y,
            0,
            player.scale,
            player.scale,
            frame.w / 2,
            frame.h / 2
        )
    else
        love.graphics.draw(player.sprite, player.x, player.y)
    end
end

return Player
