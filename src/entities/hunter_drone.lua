--[[
    A specialized enemy that inherits from EnemyBase.
    Features:
      - Vision cone with adjustable range and angle
      - Smooth chasing behavior toward player if in line of sight
      - Continuous spin when idle
      - Direction-based sprite animation from assets/sprites/hunter_drone/*
--]]

local EnemyBase = require("src/entities/enemy_base")

local HunterDrone = {}
HunterDrone.__index = HunterDrone
setmetatable(HunterDrone, { __index = EnemyBase })

local function normalize(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
end

local function dot(ax, ay, bx, by)
    return ax * bx + ay * by
end

local function rotate(dx, dy, angle)
    local c = math.cos(angle)
    local s = math.sin(angle)
    return dx * c - dy * s, dx * s + dy * c
end

local function hasSupportedImageExtension(filenameLower)
    return filenameLower:match("%.png$") or filenameLower:match("%.jpg$") or filenameLower:match("%.jpeg$")
end

local function detectDirectionFromName(filenameLower)
    if filenameLower:find("up", 1, true) then
        return "up"
    end
    if filenameLower:find("down", 1, true) then
        return "down"
    end
    if filenameLower:find("left", 1, true) then
        return "left"
    end
    if filenameLower:find("right", 1, true) then
        return "right"
    end
    return nil
end

local function loadDirectionalFrames(spriteDir)
    local frames = {
        up = {},
        down = {},
        left = {},
        right = {}
    }

    if not love or not love.filesystem or not love.graphics then
        return frames, false
    end

    if not love.filesystem.getInfo(spriteDir, "directory") then
        return frames, false
    end

    local items = love.filesystem.getDirectoryItems(spriteDir)
    table.sort(items)
    local genericFrames = {}

    for _, name in ipairs(items) do
        local lower = string.lower(name)
        if hasSupportedImageExtension(lower) then
            local fullPath = spriteDir .. "/" .. name
            local ok, imgOrErr = pcall(love.graphics.newImage, fullPath)
            if ok and imgOrErr then
                imgOrErr:setFilter("nearest", "nearest")
                local dir = detectDirectionFromName(lower)
                if dir then
                    frames[dir][#frames[dir] + 1] = imgOrErr
                else
                    genericFrames[#genericFrames + 1] = imgOrErr
                end
            end
        end
    end

    for _, dir in ipairs({ "up", "down", "left", "right" }) do
        if #frames[dir] == 0 and #genericFrames > 0 then
            for _, img in ipairs(genericFrames) do
                frames[dir][#frames[dir] + 1] = img
            end
        end
    end

    local firstDirectionalSet = nil
    for _, dir in ipairs({ "up", "down", "left", "right" }) do
        if #frames[dir] > 0 then
            firstDirectionalSet = frames[dir]
            break
        end
    end

    if firstDirectionalSet then
        for _, dir in ipairs({ "up", "down", "left", "right" }) do
            if #frames[dir] == 0 then
                frames[dir] = firstDirectionalSet
            end
        end
        return frames, true
    end

    return frames, false
end

local function directionFromVelocity(vx, vy, fallback)
    local absX = math.abs(vx or 0)
    local absY = math.abs(vy or 0)
    if absX == 0 and absY == 0 then
        return fallback or "right"
    end

    if absX >= absY then
        if (vx or 0) >= 0 then
            return "right"
        end
        return "left"
    end

    if (vy or 0) >= 0 then
        return "down"
    end
    return "up"
end

local function updateAnimationState(self, dt)
    if not self.hasDirectionalSprites then
        return
    end

    local newDirection = directionFromVelocity(self.vx, self.vy, self.animDirection)
    if newDirection ~= self.animDirection then
        self.animDirection = newDirection
        self.animFrameIndex = 1
        self.animTimer = 0
    end

    local frames = self.framesByDirection[self.animDirection] or {}
    if #frames <= 1 or ((self.vx or 0) == 0 and (self.vy or 0) == 0) then
        self.animFrameIndex = 1
        self.animTimer = 0
        return
    end

    self.animTimer = (self.animTimer or 0) + (dt or 0)
    local frameDuration = 1 / math.max(1, self.animFps or 8)
    while self.animTimer >= frameDuration do
        self.animTimer = self.animTimer - frameDuration
        self.animFrameIndex = (self.animFrameIndex % #frames) + 1
    end
end

function HunterDrone.new(opts)
    opts = opts or {}
    local base = EnemyBase.new(opts)
    local self = setmetatable(base, HunterDrone)

    -- Movement & AI properties
    self.speed = opts.speed or 140
    self.visionRange = opts.visionRange or 320
    self.dotThreshold = opts.dotThreshold or 0.5
    self.spinSpeed = opts.spinSpeed or math.pi / 4

    -- Visual properties
    self.coneColor = opts.coneColor or { 0.25, 0.8, 1.0, 0.15 }
    self.lineColor = opts.lineColor or { 0.9, 0.9, 1.0, 0.6 }
    self.lookColor = opts.lookColor or { 0.3, 0.9, 1.0, 0.8 }
    self.color = opts.color or { 0.2, 0.8, 1.0, 1.0 }
    self.scale = opts.scale or 1

    -- Direction-based sprite animation config
    self.spriteDir = opts.spriteDir or "assets/sprites/hunter_drone"
    self.animFps = opts.animFps or 8
    self.animTimer = 0
    self.animFrameIndex = 1
    self.animDirection = "right"
    self.framesByDirection, self.hasDirectionalSprites = loadDirectionalFrames(self.spriteDir)

    -- Initial look vector
    local lookX = opts.lookX or 1
    local lookY = opts.lookY or 0
    local lx, ly = normalize(lookX, lookY)
    if lx == 0 and ly == 0 then
        lx, ly = 1, 0
    end
    self.lookX = lx
    self.lookY = ly

    -- Velocity & state
    self.vx = 0
    self.vy = 0
    self.chasing = false

    return self
end

function HunterDrone:update(player, dt, playerSize)
    dt = dt or 0

    -- handle pause state (e.g., after collision)
    if self.pauseTimer and self.pauseTimer > 0 then
        self.pauseTimer = self.pauseTimer - dt
        self.vx, self.vy = 0, 0
        self.chasing = false
        updateAnimationState(self, dt)
        return
    end

    local size = playerSize or 35

    -- Calculate player center and drone center
    local px = (player and player.x or 0) + size / 2
    local py = (player and player.y or 0) + size / 2
    local cx = self.x + (self.width or 0) / 2
    local cy = self.y + (self.height or 0) / 2

    -- Vector from drone to player
    local toPx = px - cx
    local toPy = py - cy
    local dirX, dirY, dist = normalize(toPx, toPy)

    -- Determine if player is within vision range and facing
    local inRange = dist <= self.visionRange
    local facing = dot(self.lookX, self.lookY, dirX, dirY) >= self.dotThreshold
    local shouldChase = inRange and facing

    if shouldChase then
        self.chasing = true
        self.vx = dirX * self.speed
        self.vy = dirY * self.speed

        self.lookX, self.lookY = dirX, dirY
        self.spinAngle = math.atan(self.lookY, self.lookX)
    else
        self.chasing = false
        self.vx, self.vy = 0, 0

        self.spinAngle = self.spinAngle or math.atan(self.lookY or 0, self.lookX or 1)
        self.spinAngle = self.spinAngle + self.spinSpeed * dt
        if self.spinAngle > math.pi * 2 then
            self.spinAngle = self.spinAngle - math.pi * 2
        end

        self.lookX, self.lookY = rotate(1, 0, self.spinAngle)
    end

    -- Ensure look vector follows movement
    if self.vx ~= 0 or self.vy ~= 0 then
        local nx, ny = normalize(self.vx, self.vy)
        if nx ~= 0 or ny ~= 0 then
            self.lookX, self.lookY = nx, ny
        end
    end

    -- Stop when very close to player
    if self.chasing and dist < 40 then
        self.vx, self.vy = 0, 0
        updateAnimationState(self, dt)
        return
    end

    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    updateAnimationState(self, dt)
end

function HunterDrone:draw(player, playerSize)
    if not love or not love.graphics then
        return
    end

    local size = playerSize or 35
    local cx = self.x + (self.width or 0) / 2
    local cy = self.y + (self.height or 0) / 2

    -- Draw vision cone
    local coneColor = self.coneColor or { 0.2, 0.8, 1.0, 0.15 }
    local halfAngle = 1.05
    local orientation = self.spinAngle or math.atan(self.lookY, self.lookX)
    local range = self.visionRange - 20 or 400

    love.graphics.setColor(coneColor[1], coneColor[2], coneColor[3], coneColor[4] or 1)
    love.graphics.arc("fill", "pie", cx, cy, range, orientation - halfAngle, orientation + halfAngle)

    --[[
    -- DEBUGGING: draw look vector
    local lookColor = self.lookColor or {0.3,0.9,1.0,0.8}
    love.graphics.setColor(lookColor[1], lookColor[2], lookColor[3], lookColor[4] or 1)
    love.graphics.line(cx, cy, cx + self.lookX*range, cy + self.lookY*range)

    -- DEBUGGING: draw line to player
    if player then
        local px = player.x + size/2
        local py = player.y + size/2
        local lineColor = self.lineColor or {0.9,0.9,1.0,0.6}
        love.graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 1)
        love.graphics.line(cx, cy, px, py)
    end
    --]]

    if self.hasDirectionalSprites then
        local frames = self.framesByDirection[self.animDirection] or {}
        local frame = frames[self.animFrameIndex] or frames[1]
        if frame then
            local targetW = self.width or frame:getWidth()
            local targetH = self.height or frame:getHeight()
            local sx = targetW / frame:getWidth()
            local sy = targetH / frame:getHeight()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(frame, self.x, self.y, 0, sx, sy)
            love.graphics.setColor(1, 1, 1, 1)
            return
        end
    end

    -- Fallback body if sprites are missing.
    local color = self.color or { 1, 1, 1, 1 }
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width or 32, self.height or 32)
    love.graphics.setColor(1, 1, 1, 1)
end

return HunterDrone
