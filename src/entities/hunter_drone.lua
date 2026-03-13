-- Hunter drone entity: stores parameters and delegates AI/animation behavior to systems.
local EnemyBase = require("src/entities/enemy_base")
local AISystem = require("src/systems/ai_system")
local AnimationSystem = require("src/systems/animation_system")

local HunterDrone = {}
HunterDrone.__index = HunterDrone
setmetatable(HunterDrone, { __index = EnemyBase })

function HunterDrone.new(opts)
    opts = opts or {}
    local base = EnemyBase.new(opts)
    local self = setmetatable(base, HunterDrone)

    -- Movement & AI properties.
    self.speed = opts.speed or 140
    self.visionRange = opts.visionRange or 320
    self.dotThreshold = opts.dotThreshold or 0.5
    self.spinSpeed = opts.spinSpeed or math.pi / 4

    -- Visual properties.
    self.coneColor = opts.coneColor or { 0.25, 0.8, 1.0, 0.15 }
    self.detectedRingColor = opts.detectedRingColor or { 1.0, 0.25, 0.25, 0.95 }
    self.detectedFillColor = opts.detectedFillColor or { 1.0, 0.15, 0.15, 0.12 }
    self.lineColor = opts.lineColor or { 0.9, 0.9, 1.0, 0.6 }
    self.lookColor = opts.lookColor or { 0.3, 0.9, 1.0, 0.8 }
    self.color = opts.color or { 0.2, 0.8, 1.0, 1.0 }
    self.scale = opts.scale or 1

    -- Initial look vector.
    local lookX = opts.lookX or 1
    local lookY = opts.lookY or 0
    local length = math.sqrt((lookX * lookX) + (lookY * lookY))
    if length <= 0 then
        lookX, lookY = 1, 0
        length = 1
    end
    self.lookX = lookX / length
    self.lookY = lookY / length

    -- Velocity & state.
    self.isHunter = true
    self.vx = 0
    self.vy = 0
    self.state = (AISystem.HUNTER_STATES and AISystem.HUNTER_STATES.IDLE) or "idle"
    self.chasing = false
    self.detectedPlayer = false
    self.rerouteX = nil
    self.rerouteY = nil
    self.rerouteTimer = 0
    self.rerouteDuration = opts.rerouteDuration or 0.9
    self.rerouteArriveRadius = opts.rerouteArriveRadius or 20
    self.stuckTimer = 0
    self.stuckThreshold = opts.stuckThreshold or 0.4
    self.stuckMoveEpsilon = opts.stuckMoveEpsilon or 4
    self.stuckSampleX = nil
    self.stuckSampleY = nil
    self.lastBlockedNode = nil
    self.blockedNodeTimer = 0
    self.blockedNodeMemory = opts.blockedNodeMemory or 1.2
    self.lastTargetX = nil
    self.lastTargetY = nil

    AnimationSystem.attachDirectional(self, {
        spriteDir = opts.spriteDir or "assets/sprites/hunter_drone",
        animFps = opts.animFps or 8,
        defaultDirection = "right"
    })

    return self
end

function HunterDrone:update(player, dt, playerSize)
    dt = dt or 0
    EnemyBase.updateStunFlicker(self, dt)
    AISystem.updateHunter(self, player, dt, playerSize)
    AnimationSystem.updateDirectional(self, dt)
end

function HunterDrone:draw(player, playerSize)
    if not love or not love.graphics then
        return
    end

    local cx = self.x + (self.width or 0) / 2
    local cy = self.y + (self.height or 0) / 2
    local alpha = EnemyBase.getStunFlickerAlpha(self)

    if self.detectedPlayer then
        local fill = self.detectedFillColor or { 1.0, 0.15, 0.15, 0.12 }
        local ring = self.detectedRingColor or { 1.0, 0.25, 0.25, 0.95 }
        local radius = (self.visionRange or 400) - 20
        love.graphics.setColor(fill[1], fill[2], fill[3], (fill[4] or 1) * alpha)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setLineWidth(3)
        love.graphics.setColor(ring[1], ring[2], ring[3], (ring[4] or 1) * alpha)
        love.graphics.circle("line", cx, cy, radius)
        love.graphics.setLineWidth(1)
    else
        local coneColor = self.coneColor or { 0.2, 0.8, 1.0, 0.15 }
        local halfAngle = 1.05
        local orientation = self.spinAngle or math.atan(self.lookY or 0, self.lookX or 1)
        local range = (self.visionRange or 400) - 20
        love.graphics.setColor(coneColor[1], coneColor[2], coneColor[3], (coneColor[4] or 1) * alpha)
        love.graphics.arc("fill", "pie", cx, cy, range, orientation - halfAngle, orientation + halfAngle)
    end

    if AnimationSystem.drawDirectional(self, alpha) then
        return
    end

    local color = self.color or { 1, 1, 1, 1 }
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width or 32, self.height or 32)
    love.graphics.setColor(1, 1, 1, 1)
end

return HunterDrone
