--[[
    A patrolling enemy that moves back and forth between two points.
    Inherits from EnemyBase and supports:
      - Adjustable patrol points (x1,y1 -> x2,y2)
      - Pausing at patrol points
      - Smooth movement with arrival threshold
      - Optional sprite drawing or default rectangle
--]]

-- Base enemy class
local EnemyBase = require("src/entities/enemy_base")

-- PatrolDrone class
local PatrolDrone = {}
PatrolDrone.__index = PatrolDrone
setmetatable(PatrolDrone, { __index = EnemyBase }) -- inherit EnemyBase

local SPRITE_CACHE = {}

local function normalize(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
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

local function getDirectionalFrames(spriteDir)
    local cached = SPRITE_CACHE[spriteDir]
    if cached then
        return cached.frames, cached.hasDirectionalSprites
    end

    local frames, hasDirectionalSprites = loadDirectionalFrames(spriteDir)
    SPRITE_CACHE[spriteDir] = {
        frames = frames,
        hasDirectionalSprites = hasDirectionalSprites
    }
    return frames, hasDirectionalSprites
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

-- Determine current patrol target based on direction
local function getTarget(self)
    if self.forward then
        return self.x2, self.y2
    end
    return self.x1, self.y1
end

-- Constructor
function PatrolDrone.new(opts)
    opts = opts or {}
    local base = EnemyBase.new(opts)
    local self = setmetatable(base, PatrolDrone)

    -- Patrol points
    self.x1 = opts.x1 or self.x or 0
    self.y1 = opts.y1 or self.y or 0
    self.x2 = opts.x2 or self.x1
    self.y2 = opts.y2 or self.y1

    -- Movement properties
    self.speed = opts.speed or 80
    self.arriveThreshold = opts.arriveThreshold or 2  -- distance to target considered "arrived"
    self.pauseDuration = opts.pauseDuration or 0       -- time to pause at endpoints
    self.pauseTimer = 0

    -- Direction state
    if opts.forward == nil then
        self.forward = true
    else
        self.forward = opts.forward and true or false
    end

    -- Velocity
    self.vx = 0
    self.vy = 0

    -- Visuals
    self.sprite = opts.sprite
    self.color = opts.color or { 1, 1, 1, 1 }
    self.scale = opts.scale or 1

    -- Direction-based sprite animation config
    self.spriteDir = opts.spriteDir or "assets/sprites/patrol_drone"
    self.animFps = opts.animFps or 8
    self.animTimer = 0
    self.animFrameIndex = 1
    self.animDirection = "right"
    self.framesByDirection, self.hasDirectionalSprites = getDirectionalFrames(self.spriteDir)

    return self
end

-- Patrol Points Setter
function PatrolDrone:setPatrolPoints(x1, y1, x2, y2)
    if x1 ~= nil then self.x1 = x1 end
    if y1 ~= nil then self.y1 = y1 end
    if x2 ~= nil then self.x2 = x2 end
    if y2 ~= nil then self.y2 = y2 end
end

function PatrolDrone:update(dt)
    dt = dt or 0
    EnemyBase.updateStunFlicker(self, dt)

    -- Handle pause at patrol points
    if self.pauseTimer and self.pauseTimer > 0 then
        self.pauseTimer = math.max(0, self.pauseTimer - dt)
        self.vx = 0
        self.vy = 0
        self.chasing = false
        updateAnimationState(self, dt)
        return
    end

    -- Get target patrol point
    local tx, ty = getTarget(self)

    -- Vector to target
    local dx = tx - self.x
    local dy = ty - self.y
    local nx, ny, dist = normalize(dx, dy)

    local speed = self.speed or 0

    -- Check if arrived at target or speed is zero
    if dist <= (self.arriveThreshold or 0) or speed <= 0 then
        -- Snap to target
        self.x, self.y = tx, ty
        self.vx, self.vy = 0, 0

        -- Reverse direction
        self.forward = not self.forward

        -- Start pause timer if applicable
        if (self.pauseDuration or 0) > 0 then
            self.pauseTimer = self.pauseDuration
        end
        updateAnimationState(self, dt)
        return
    end

    -- Calculate step based on speed and dt
    local step = speed * dt
    if step >= dist then
        -- Arrive exactly at target and reverse direction
        self.x, self.y = tx, ty
        self.vx, self.vy = 0, 0
        self.forward = not self.forward
        if (self.pauseDuration or 0) > 0 then
            self.pauseTimer = self.pauseDuration
        end
        updateAnimationState(self, dt)
        return
    end

    -- Move toward target
    self.vx = nx * speed
    self.vy = ny * speed
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    updateAnimationState(self, dt)
end

function PatrolDrone:draw()
    if not love or not love.graphics then
        return
    end
    local alpha = EnemyBase.getStunFlickerAlpha(self)

    if self.sprite then
        -- Draw sprite with scaling
        local sprite = self.sprite
        local scale = self.scale or 1
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(sprite, self.x, self.y, 0, scale, scale)
    elseif self.hasDirectionalSprites then
        local frames = self.framesByDirection[self.animDirection] or {}
        local frame = frames[self.animFrameIndex] or frames[1]
        if frame then
            local targetW = self.width or frame:getWidth()
            local targetH = self.height or frame:getHeight()
            local sx = targetW / frame:getWidth()
            local sy = targetH / frame:getHeight()
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(frame, self.x, self.y, 0, sx, sy)
        else
            local color = self.color or { 1, 1, 1, 1 }
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
            love.graphics.rectangle("fill", self.x, self.y, self.width or 32, self.height or 32)
        end
    else
        -- Draw placeholder rectangle if no sprite
        local w = self.width or 32
        local h = self.height or 32
        local color = self.color or { 1, 1, 1, 1 }
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
        love.graphics.rectangle("fill", self.x, self.y, w, h)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return PatrolDrone
