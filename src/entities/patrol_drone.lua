local EnemyBase = require("src/entities/enemy_base")

local PatrolDrone = {}
PatrolDrone.__index = PatrolDrone
setmetatable(PatrolDrone, { __index = EnemyBase })

local function normalize(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then
        return 0, 0, 0
    end
    return dx / len, dy / len, len
end

local function getTarget(self)
    if self.forward then
        return self.x2, self.y2
    end
    return self.x1, self.y1
end

function PatrolDrone.new(opts)
    opts = opts or {}
    local base = EnemyBase.new(opts)
    local self = setmetatable(base, PatrolDrone)

    self.x1 = opts.x1 or self.x or 0
    self.y1 = opts.y1 or self.y or 0
    self.x2 = opts.x2 or self.x1
    self.y2 = opts.y2 or self.y1

    self.speed = opts.speed or 80
    self.arriveThreshold = opts.arriveThreshold or 2
    self.pauseDuration = opts.pauseDuration or 0
    self.pauseTimer = 0
    if opts.forward == nil then
        self.forward = true
    else
        self.forward = opts.forward and true or false
    end

    self.vx = 0
    self.vy = 0

    self.sprite = opts.sprite
    self.color = opts.color or { 1, 1, 1, 1 }
    self.scale = opts.scale or 1

    return self
end

function PatrolDrone:setPatrolPoints(x1, y1, x2, y2)
    if x1 ~= nil then self.x1 = x1 end
    if y1 ~= nil then self.y1 = y1 end
    if x2 ~= nil then self.x2 = x2 end
    if y2 ~= nil then self.y2 = y2 end
end

function PatrolDrone:update(dt)
    dt = dt or 0

    if self.pauseTimer and self.pauseTimer > 0 then
        self.pauseTimer = math.max(0, self.pauseTimer - dt)
        self.vx = 0
        self.vy = 0
        return
    end

    local tx, ty = getTarget(self)
    local dx = tx - self.x
    local dy = ty - self.y
    local nx, ny, dist = normalize(dx, dy)

    local speed = self.speed or 0
    if dist <= (self.arriveThreshold or 0) or speed <= 0 then
        self.x = tx
        self.y = ty
        self.vx = 0
        self.vy = 0
        self.forward = not self.forward
        if (self.pauseDuration or 0) > 0 then
            self.pauseTimer = self.pauseDuration
        end
        return
    end

    local step = speed * dt
    if step >= dist then
        self.x = tx
        self.y = ty
        self.vx = 0
        self.vy = 0
        self.forward = not self.forward
        if (self.pauseDuration or 0) > 0 then
            self.pauseTimer = self.pauseDuration
        end
        return
    end

    self.vx = nx * speed
    self.vy = ny * speed
    self.x = self.x + nx * step
    self.y = self.y + ny * step
end

function PatrolDrone:draw()
    if not love or not love.graphics then
        return
    end

    local color = self.color or { 1, 1, 1, 1 }
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)

    if self.sprite then
        local sprite = self.sprite
        local scale = self.scale or 1
        love.graphics.draw(sprite, self.x, self.y, 0, scale, scale)
    else
        local w = self.width or 32
        local h = self.height or 32
        love.graphics.rectangle("fill", self.x, self.y, w, h)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return PatrolDrone
