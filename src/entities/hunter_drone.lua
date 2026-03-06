--[[ 
    HunterDrone.lua
    A specialized enemy that inherits from EnemyBase. 
    Features:
      - Vision cone with adjustable range and angle
      - Smooth chasing behavior toward player if in line of sight
      - Continuous spin when idle
      - Debug-friendly drawing for development
--]]

-- Base enemy class
local EnemyBase = require("src/entities/enemy_base")

-- HunterDrone class
local HunterDrone = {}
HunterDrone.__index = HunterDrone
setmetatable(HunterDrone, { __index = EnemyBase }) -- inherit from EnemyBase

-- Utility Functions

-- Normalize a vector (dx, dy), return unit vector and length
local function normalize(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
end

-- Dot product of two 2D vectors
local function dot(ax, ay, bx, by)
    return ax * bx + ay * by
end

-- Rotate a vector by a given angle (radians)
local function rotate(dx, dy, angle)
    local c = math.cos(angle)
    local s = math.sin(angle)
    return dx * c - dy * s, dx * s + dy * c
end

-- Constructor
function HunterDrone.new(opts)
    opts = opts or {}
    local base = EnemyBase.new(opts)  -- initialize base enemy
    local self = setmetatable(base, HunterDrone)

    -- Movement & AI properties
    self.speed = opts.speed or 140
    self.visionRange = opts.visionRange or 320
    self.dotThreshold = opts.dotThreshold or 0.5 -- angle tolerance for chasing
    self.spinSpeed = opts.spinSpeed or math.pi/4  -- radians/sec rotation when idle

    -- Visual properties
    self.coneColor = opts.coneColor or { 0.25, 0.8, 1.0, 0.15 } -- vision cone
    self.lineColor = opts.lineColor or { 0.9, 0.9, 1.0, 0.6 }  -- debug line to player
    self.lookColor = opts.lookColor or { 0.3, 0.9, 1.0, 0.8 }  -- debug look vector
    self.color = opts.color or { 0.2, 0.8, 1.0, 1.0 }          -- drone body
    self.scale = opts.scale or 1

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
        return
    end

    local size = playerSize or 35

    -- Store previous position for potential collision handling
    self.prevX = self.x
    self.prevY = self.y

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
        -- Move towards player
        self.chasing = true
        self.vx = dirX * self.speed
        self.vy = dirY * self.speed

        -- Snap look vector and spinAngle to player
        self.lookX, self.lookY = dirX, dirY
        self.spinAngle = math.atan(self.lookY, self.lookX)
    else
        -- Idle spinning behavior
        self.chasing = false
        self.vx, self.vy = 0, 0

        -- initialize spinAngle if missing
        self.spinAngle = self.spinAngle or math.atan(self.lookY or 0, self.lookX or 1)

        -- continuous rotation
        self.spinAngle = self.spinAngle + self.spinSpeed * dt
        if self.spinAngle > math.pi*2 then
            self.spinAngle = self.spinAngle - math.pi*2
        end

        -- update look vector from spinAngle
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
        return
    end

    -- Apply velocity to position
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
end



function HunterDrone:draw(player, playerSize)
    if not love or not love.graphics then return end

    local size = playerSize or 35
    local cx = self.x + (self.width or 0)/2
    local cy = self.y + (self.height or 0)/2

    -- Draw vision cone
    local coneColor = self.coneColor or {0.2,0.8,1.0,0.15}
    local halfAngle = 1.1 -- radians (~125 degrees total)
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

    -- Draw drone body (currently a rectangle)
    local color = self.color or {1,1,1,1}
    love.graphics.setColor(color[1],color[2],color[3],color[4] or 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width or 32, self.height or 32)
    love.graphics.setColor(1,1,1,1)
end

return HunterDrone