-- Shared random/grid search helpers for spawn placement and fallback scans.
local SearchUtils = {}

function SearchUtils.findRandomValue(minValue, maxValue, attempts, isValid, rng)
    local minV = minValue or 0
    local maxV = maxValue or 0
    local tries = math.max(0, math.floor(attempts or 0))
    local random = rng or ((love and love.math and love.math.random) or math.random)
    local validator = isValid or function()
        return false
    end

    for _ = 1, tries do
        local value = random(minV, maxV)
        if validator(value) then
            return value
        end
    end

    return nil
end

function SearchUtils.findRandom(bounds, attempts, isValid, rng)
    local minX = bounds and bounds.minX or 0
    local maxX = bounds and bounds.maxX or 0
    local minY = bounds and bounds.minY or 0
    local maxY = bounds and bounds.maxY or 0
    local tries = math.max(0, math.floor(attempts or 0))
    local random = rng or ((love and love.math and love.math.random) or math.random)
    local validator = isValid or function()
        return false
    end

    for _ = 1, tries do
        local x = random(minX, maxX)
        local y = random(minY, maxY)
        if validator(x, y) then
            return x, y
        end
    end

    return nil, nil
end

function SearchUtils.findGrid(bounds, step, isValid, opts)
    local minX = bounds and bounds.minX or 0
    local maxX = bounds and bounds.maxX or 0
    local minY = bounds and bounds.minY or 0
    local maxY = bounds and bounds.maxY or 0
    local scanStep = math.max(1, math.floor(step or 1))
    local random = (opts and opts.rng) or ((love and love.math and love.math.random) or math.random)
    local wrap = opts and opts.wrap == true
    local validator = isValid or function()
        return false
    end

    local startX = minX
    local startY = minY
    if opts and opts.randomStart then
        startX = random(minX, maxX)
        startY = random(minY, maxY)
    end

    if wrap then
        local rangeX = math.max(1, (maxX - minX) + 1)
        local rangeY = math.max(1, (maxY - minY) + 1)
        for oy = 0, maxY - minY, scanStep do
            local y = minY + ((startY - minY + oy) % rangeY)
            for ox = 0, maxX - minX, scanStep do
                local x = minX + ((startX - minX + ox) % rangeX)
                if validator(x, y) then
                    return x, y
                end
            end
        end
    else
        for y = minY, maxY, scanStep do
            for x = minX, maxX, scanStep do
                if validator(x, y) then
                    return x, y
                end
            end
        end
    end

    return nil, nil
end

function SearchUtils.findGridValue(minValue, maxValue, step, isValid)
    local minV = minValue or 0
    local maxV = maxValue or 0
    local scanStep = math.max(1, math.floor(step or 1))
    local validator = isValid or function()
        return false
    end

    for value = minV, maxV, scanStep do
        if validator(value) then
            return value
        end
    end

    return nil
end

function SearchUtils.findRandomThenGrid(bounds, randomAttempts, step, isValid, opts)
    local random = (opts and opts.rng) or ((love and love.math and love.math.random) or math.random)
    local x, y = SearchUtils.findRandom(bounds, randomAttempts, isValid, random)
    if x ~= nil and y ~= nil then
        return x, y
    end

    return SearchUtils.findGrid(bounds, step, isValid, opts)
end

function SearchUtils.findRandomThenGridValue(minValue, maxValue, randomAttempts, step, isValid, rng)
    local value = SearchUtils.findRandomValue(minValue, maxValue, randomAttempts, isValid, rng)
    if value ~= nil then
        return value
    end

    return SearchUtils.findGridValue(minValue, maxValue, step, isValid)
end

return SearchUtils
