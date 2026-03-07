-- Utility for extracting frame quads from sprite sheets that use transparent spacing.
local SpriteSheet = {}

function SpriteSheet.buildFrames(imagePath, options)
    -- Scan rows and columns for opaque regions, then build quads for each detected frame.
    local opts = options or {}
    local alphaLimit = opts.alphaCutoff or 0.05
    local emptyThreshold = opts.emptyFrac or 0.98

    local image = love.graphics.newImage(imagePath)
    local imageData = love.image.newImageData(imagePath)
    local w, h = imageData:getDimensions()

    local function buildSegments(isRow)
        local segments = {}
        local major = isRow and h or w
        local minor = isRow and w or h
        local start = nil

        for i = 0, major - 1 do
            local transparent = 0
            for j = 0, minor - 1 do
                local x = isRow and j or i
                local y = isRow and i or j
                local _, _, _, a = imageData:getPixel(x, y)
                if a <= alphaLimit then
                    transparent = transparent + 1
                end
            end

            local empty = (transparent / minor) >= emptyThreshold
            if not empty and start == nil then
                start = i
            elseif empty and start ~= nil then
                table.insert(segments, { start, i - 1 })
                start = nil
            end
        end

        if start ~= nil then
            table.insert(segments, { start, major - 1 })
        end

        return segments
    end

    local cols = buildSegments(false)
    local rows = buildSegments(true)
    local frames = {}

    local function cellHasPixels(col, row)
        for y = row[1], row[2] do
            for x = col[1], col[2] do
                local _, _, _, a = imageData:getPixel(x, y)
                if a > alphaLimit then
                    return true
                end
            end
        end
        return false
    end

    for _, row in ipairs(rows) do
        for _, col in ipairs(cols) do
            if cellHasPixels(col, row) then
                local x = col[1]
                local y = row[1]
                local cw = col[2] - col[1] + 1
                local rh = row[2] - row[1] + 1
                local quad = love.graphics.newQuad(x, y, cw, rh, w, h)
                table.insert(frames, { quad = quad, w = cw, h = rh })
            end
        end
    end

    if #frames == 0 then
        local quad = love.graphics.newQuad(0, 0, w, h, w, h)
        table.insert(frames, { quad = quad, w = w, h = h })
    end

    return {
        image = image,
        frames = frames,
        width = w,
        height = h
    }
end

return SpriteSheet
