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

function HunterDrone.new(opts)
    opts = opts or {}
    local base = EnemyBase.new(opts)
    local self = setmetatable(base, HunterDrone)

    self.speed = opts.speed or 140
    self.visionRange = opts.visionRange or 320
    self.dotThreshold = opts.dotThreshold or 0.5
    self.coneColor = opts.coneColor or { 0.25, 0.8, 1.0, 0.15 }
    self.lineColor = opts.lineColor or { 0.9, 0.9, 1.0, 0.6 }
    self.lookColor = opts.lookColor or { 0.3, 0.9, 1.0, 0.8 }
    self.color = opts.color or { 0.2, 0.8, 1.0, 1.0 }
    self.scale = opts.scale or 1

    local lookX = opts.lookX or 1
    local lookY = opts.lookY or 0
    local lx, ly = normalize(lookX, lookY)
    if lx == 0 and ly == 0 then
        lx, ly = 1, 0
    end
    self.lookX = lx
    self.lookY = ly

    self.vx = 0
    self.vy = 0
    self.chasing = false

    return self
end

function HunterDrone:update(player, dt, playerSize)
    dt = dt or 0
    local size = playerSize or 35

    local px = (player and player.x or 0) + size / 2
    local py = (player and player.y or 0) + size / 2
    local cx = self.x + (self.width or 0) / 2
    local cy = self.y + (self.height or 0) / 2

    local toPx = px - cx
    local toPy = py - cy
    local dirX, dirY, dist = normalize(toPx, toPy)

    local inRange = dist <= (self.visionRange or 0)
    local facing = dot(self.lookX, self.lookY, dirX, dirY) >= (self.dotThreshold or 0.5)
    local shouldChase = inRange and facing

    if shouldChase then
        self.chasing = true
        self.vx = dirX * (self.speed or 0)
        self.vy = dirY * (self.speed or 0)
    else
        self.chasing = false
        self.vx = 0
        self.vy = 0
    end

    if self.vx ~= 0 or self.vy ~= 0 then
        local nx, ny = normalize(self.vx, self.vy)
        if nx ~= 0 or ny ~= 0 then
            self.lookX = nx
            self.lookY = ny
        end
    end

    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
end

function HunterDrone:draw(player, playerSize)
    if not love or not love.graphics then
        return
    end

    local size = playerSize or 35
    local cx = self.x + (self.width or 0) / 2
    local cy = self.y + (self.height or 0) / 2

    local range = self.visionRange or 0
    local threshold = self.dotThreshold or 0.5
    local angle = math.acos(math.max(-1, math.min(1, threshold)))
    local leftX, leftY = rotate(self.lookX, self.lookY, -angle)
    local rightX, rightY = rotate(self.lookX, self.lookY, angle)

    local coneColor = self.coneColor or { 0.2, 0.8, 1.0, 0.15 }
    love.graphics.setColor(coneColor[1], coneColor[2], coneColor[3], coneColor[4] or 1)
    love.graphics.polygon(
        "fill",
        cx,
        cy,
        cx + leftX * range,
        cy + leftY * range,
        cx + rightX * range,
        cy + rightY * range
    )

    local lookColor = self.lookColor or { 0.3, 0.9, 1.0, 0.8 }
    love.graphics.setColor(lookColor[1], lookColor[2], lookColor[3], lookColor[4] or 1)
    love.graphics.line(cx, cy, cx + self.lookX * range, cy + self.lookY * range)

    if player then
        local px = player.x + size / 2
        local py = player.y + size / 2
        local lineColor = self.lineColor or { 0.9, 0.9, 1.0, 0.6 }
        love.graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 1)
        love.graphics.line(cx, cy, px, py)
    end

    local color = self.color or { 1, 1, 1, 1 }
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width or 32, self.height or 32)
    love.graphics.setColor(1, 1, 1, 1)
end

return HunterDrone
