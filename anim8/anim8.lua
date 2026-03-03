local Anim8 = {}

local function toIndexList(value)
    local t = type(value)
    if t == "number" then
        return { value }
    end
    if t == "table" then
        return value
    end
    if t ~= "string" then
        return {}
    end

    local single = tonumber(value)
    if single then
        return { single }
    end

    local startStr, stopStr = value:match("^(%d+)%s*%-%s*(%d+)$")
    if not startStr then
        return {}
    end

    local startNum = tonumber(startStr)
    local stopNum = tonumber(stopStr)
    local step = startNum <= stopNum and 1 or -1
    local list = {}
    for i = startNum, stopNum, step do
        list[#list + 1] = i
    end
    return list
end

function Anim8.newGrid(frameW, frameH, imageW, imageH, left, top, spacing)
    local offsetX = left or 0
    local offsetY = top or 0
    local gap = spacing or 0

    return function(cols, rows)
        local colList = toIndexList(cols)
        local rowList = toIndexList(rows)
        local frames = {}

        for _, row in ipairs(rowList) do
            for _, col in ipairs(colList) do
                local x = offsetX + (col - 1) * (frameW + gap)
                local y = offsetY + (row - 1) * (frameH + gap)
                local quad = love.graphics.newQuad(x, y, frameW, frameH, imageW, imageH)
                frames[#frames + 1] = { quad = quad, w = frameW, h = frameH }
            end
        end

        return frames
    end
end

function Anim8.newAnimation(frames, frameDuration)
    local anim = {
        frames = frames or {},
        frameDuration = frameDuration or 0.1,
        frameTimer = 0,
        frameIndex = 1
    }

    function anim:update(dt)
        if #self.frames <= 1 or self.frameDuration <= 0 then
            return
        end
        self.frameTimer = self.frameTimer + dt
        while self.frameTimer >= self.frameDuration do
            self.frameTimer = self.frameTimer - self.frameDuration
            self.frameIndex = (self.frameIndex % #self.frames) + 1
        end
    end

    function anim:gotoFrame(index)
        if #self.frames == 0 then
            return
        end
        local idx = tonumber(index) or 1
        self.frameIndex = math.max(1, math.min(idx, #self.frames))
        self.frameTimer = 0
    end

    function anim:getFrame()
        return self.frames[self.frameIndex]
    end

    function anim:draw(image, x, y, r, sx, sy, ox, oy)
        if not image then
            return
        end
        local frame = self.frames[self.frameIndex]
        if not frame then
            love.graphics.draw(image, x or 0, y or 0)
            return
        end
        love.graphics.draw(
            image,
            frame.quad,
            x or 0,
            y or 0,
            r or 0,
            sx or 1,
            sy or 1,
            ox or 0,
            oy or 0
        )
    end

    return anim
end

return Anim8
