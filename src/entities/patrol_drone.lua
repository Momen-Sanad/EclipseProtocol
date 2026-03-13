-- Patrol drone entity: owns state fields and delegates AI/animation behavior to systems.
local EnemyBase = require("src/entities/enemy_base")
local AISystem = require("src/systems/ai_system")
local AnimationSystem = require("src/systems/animation_system")

local PatrolDrone = {}
PatrolDrone.__index = PatrolDrone
setmetatable(PatrolDrone, { __index = EnemyBase })

function PatrolDrone.new(opts)
    opts = opts or {}
    local base = EnemyBase.new(opts)
    local self = setmetatable(base, PatrolDrone)

    -- Patrol points.
    self.x1 = opts.x1 or self.x or 0
    self.y1 = opts.y1 or self.y or 0
    self.x2 = opts.x2 or self.x1
    self.y2 = opts.y2 or self.y1

    -- Movement properties.
    self.speed = opts.speed or 80
    self.arriveThreshold = opts.arriveThreshold or 2
    self.pauseDuration = opts.pauseDuration or 0
    self.pauseTimer = 0

    -- Direction state.
    if opts.forward == nil then
        self.forward = true
    else
        self.forward = opts.forward and true or false
    end

    -- Velocity.
    self.vx = 0
    self.vy = 0
    self.state = "patrol"

    -- Visual fallback.
    self.sprite = opts.sprite
    self.color = opts.color or { 1, 1, 1, 1 }
    self.scale = opts.scale or 1

    AnimationSystem.attachDirectional(self, {
        spriteDir = opts.spriteDir or "assets/sprites/patrol_drone",
        animFps = opts.animFps or 8,
        defaultDirection = "right"
    })

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
    EnemyBase.updateStunFlicker(self, dt)
    AISystem.updatePatrol(self, dt)
    AnimationSystem.updateDirectional(self, dt)
end

function PatrolDrone:draw()
    if not love or not love.graphics then
        return
    end

    local alpha = EnemyBase.getStunFlickerAlpha(self)

    if self.sprite then
        local sprite = self.sprite
        local scale = self.scale or 1
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(sprite, self.x, self.y, 0, scale, scale)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    if AnimationSystem.drawDirectional(self, alpha) then
        return
    end

    local w = self.width or 32
    local h = self.height or 32
    local color = self.color or { 1, 1, 1, 1 }
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
    love.graphics.rectangle("fill", self.x, self.y, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

return PatrolDrone
