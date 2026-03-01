local AudioSystem = {}

local musicSource = nil
local musicPath = nil
local musicVolume = 0.8
local sfxVolume = 0.9
local sfxCache = {}

local function loadSource(path, kind)
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
    src:play()
    musicSource = src
    musicPath = path
end

function AudioSystem.stopMusic()
    if musicSource then
        musicSource:stop()
        musicSource = nil
        musicPath = nil
    end
end

function AudioSystem.playSfx(path, opts)
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

return AudioSystem
