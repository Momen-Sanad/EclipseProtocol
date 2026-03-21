-- Centralized music/SFX helper for loading, caching, and runtime volume control.
local AudioSystem = {}

-- Music is treated as a single active track, while SFX are cached and cloned per play.
local musicSource = nil
local musicPath = nil
local musicVolume = 0.8
local sfxVolume = 0.9
local sfxCache = {}
local globalPlaybackScale = 1.0
local sourceBasePitches = setmetatable({}, { __mode = "k" })

local function clamp(value, minValue, maxValue)
    if value == nil then
        return minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function resetTrackedSourcePitches()
    sourceBasePitches = setmetatable({}, { __mode = "k" })
end

local function applyGlobalPlaybackScale()
    if not (love and love.audio and love.audio.getActiveSources) then
        return
    end

    local activeSources = love.audio.getActiveSources()
    for _, src in ipairs(activeSources or {}) do
        if src and src.getPitch and src.setPitch then
            local basePitch = sourceBasePitches[src]
            if not basePitch then
                basePitch = math.max(0.01, src:getPitch() or 1.0)
                sourceBasePitches[src] = basePitch
            end
            src:setPitch(basePitch * globalPlaybackScale)
        end
    end
end

local function loadSource(path, kind)
    -- Missing audio should fail softly so gameplay can continue.
    if not path or path == "" then
        return nil
    end

    if not love.filesystem.getInfo(path) then
        print("Audio file not found: " .. tostring(path))
        return nil
    end

    local ok, srcOrErr = pcall(love.audio.newSource, path, kind)
    if not ok then
        print("Audio load failed for " .. tostring(path) .. ": " .. tostring(srcOrErr))
        return nil
    end

    return srcOrErr
end

function AudioSystem.init(config)
    -- Stores default mix levels and optionally starts a boot track.
    local cfg = config or {}
    if cfg.musicVolume then
        musicVolume = cfg.musicVolume
    end
    if cfg.sfxVolume then
        sfxVolume = cfg.sfxVolume
    end
    if cfg.music then
        AudioSystem.playMusic(cfg.music)
    end
end

function AudioSystem.playMusic(path, opts)
    -- Starting new music always replaces the currently playing track.
    if musicSource then
        musicSource:stop()
        musicSource = nil
        musicPath = nil
    end

    if not path or path == "" then
        return
    end

    local src = loadSource(path, "stream")
    if not src then
        return
    end

    local loop = true
    local volume = musicVolume
    if opts then
        if opts.loop ~= nil then
            loop = opts.loop
        end
        if opts.volume ~= nil then
            volume = opts.volume
        end
    end

    src:setLooping(loop)
    src:setVolume(volume)
    src:setPitch(1.0)
    src:play()
    musicSource = src
    musicPath = path
    applyGlobalPlaybackScale()
end

function AudioSystem.stopMusic()
    if musicSource then
        musicSource:stop()
        musicSource = nil
        musicPath = nil
    end
end

function AudioSystem.stopAll()
    -- Ensure transition screens can hard-cut all active audio, including cloned SFX.
    if love and love.audio and love.audio.stop then
        love.audio.stop()
    end
    musicSource = nil
    musicPath = nil
    resetTrackedSourcePitches()
end

function AudioSystem.playSfx(path, opts)
    -- Reuse a cached template so repeated SFX can overlap without reloading from disk.
    local template = sfxCache[path]
    if not template then
        template = loadSource(path, "static")
        if not template then
            return
        end
        sfxCache[path] = template
    end

    local src = template:clone()
    if not src then
        return
    end

    local volume = sfxVolume
    local pitch = 1.0
    local loop = false
    if opts then
        if opts.volume ~= nil then
            volume = opts.volume
        end
        if opts.pitch ~= nil then
            pitch = opts.pitch
        end
        if opts.loop ~= nil then
            loop = opts.loop
        end
    end

    src:setLooping(loop)
    src:setVolume(volume)
    src:setPitch(pitch)
    src:play()
    applyGlobalPlaybackScale()
end

function AudioSystem.setMusicVolume(volume)
    if volume == nil then
        return
    end
    musicVolume = math.max(0, math.min(1, volume))
    if musicSource then
        musicSource:setVolume(musicVolume)
    end
end

function AudioSystem.setSfxVolume(volume)
    if volume == nil then
        return
    end
    sfxVolume = math.max(0, math.min(1, volume))
end

function AudioSystem.getMusicVolume()
    return musicVolume
end

function AudioSystem.getSfxVolume()
    return sfxVolume
end

function AudioSystem.getCurrentMusic()
    return musicPath
end

function AudioSystem.setCurrentMusicVolume(volume)
    if volume == nil then
        return
    end
    -- Temporary fades should not overwrite the saved global music volume.
    if musicSource then
        musicSource:setVolume(math.max(0, math.min(1, volume)))
    end
end

function AudioSystem.setGlobalPlaybackScale(scale)
    local nextScale = clamp(scale or 1.0, 0.5, 2.0)
    if math.abs(nextScale - globalPlaybackScale) <= 0.0001 then
        return
    end

    globalPlaybackScale = nextScale
    applyGlobalPlaybackScale()
end

function AudioSystem.getGlobalPlaybackScale()
    return globalPlaybackScale
end

function AudioSystem.refreshGlobalPlaybackScale()
    applyGlobalPlaybackScale()
end

return AudioSystem
