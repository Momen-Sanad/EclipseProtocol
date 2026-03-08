-- Main LÖVE bootstrap: configures shared game context and forwards engine callbacks.
local AudioSystem = require("src/systems/audio_system")
local StateManager = require("src/core/state_manager")
local MenuState = require("src/states/menu")
local LevelSelectState = require("src/states/level_select")
local GameState = require("src/states/game")
local TransitionState = require("src/states/transition")
local PauseState = require("src/states/pause")
local VictoryState = require("src/states/victory")
local GameOverState = require("src/states/gameover")

WINDOW_WIDTH = 1920
WINDOW_HEIGHT = 1080

VIRTUAL_WIDTH = 2
VIRTUAL_HEIGHT = 1

PLAYER_SIZE = 100

-- Shared audio paths live in the root config so states and entities can reuse them.
local MENU_MUSIC_PATH = "assets/audio/music/StartMenu.mp3"
local GAME_MUSIC_PATH = nil
local TRANSITION_DURATION = 2.5
local FADE_DURATION = 0.5

function love.load()
    -- Build global runtime configuration once, then let states pull from StateManager.context.
    local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
    WINDOW_WIDTH = desktopWidth or WINDOW_WIDTH
    WINDOW_HEIGHT = desktopHeight or WINDOW_HEIGHT

    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = true,
        fullscreentype = "desktop",
        resizable = false
    })
    love.graphics.setDefaultFilter("linear", "linear", 16)
    love.math.setRandomSeed(os.time())

    -- Initialize the audio system before any state tries to play music or SFX.
    AudioSystem.init({
        musicVolume = 0.8,
        sfxVolume = 0.9
    })

    StateManager.init({
        windowWidth = WINDOW_WIDTH,
        windowHeight = WINDOW_HEIGHT,
        backgroundPath = "assets/ui/background.png",
        patrolDroneSpritePath = "assets/sprites/player/Patrol Drone.png",
        hunterDroneSpritePath = "assets/sprites/player/Hunter Drone.png",
        playerSpritePath = "assets/sprites/player/Robot.png",
        playerSize = PLAYER_SIZE,
        playerSpeed = 300,
        playerMoveStartSpeed = 110,
        playerMoveRampDuration = 0.45,
        playerFrameDuration = 0.12,
        playerAnimMode = "state",
        playerStateFrameCounts = { idle = 5, run = 6, dash = 4 },
        playerStateRows = { idle = 1, run = 2, dash = 3 },
        playerDashSpeed = 400,
        playerDashDuration = 0.35,
        playerDashCooldown = 5.0,
        playerDashEnergyCost = 20,
        stunGunEnergyCost = 60,
        stunGunCooldown = 20.0,
        stunGunRange = 520,
        stunGunStunDuration = 5.0,
        stunGunLaserLifetime = 0.12,
        energyCellRestore = 15,
        powerNodeSize = 120,
        powerNodeCount = 3,
        powerNodeInteractRange = 170,
        powerNodeRepairDuration = 5.0,
        -- Audio settings are passed through the shared state context.
        dashSoundPath = "assets/audio/sfx/Dash.wav",
        footstepSoundPath = "assets/audio/sfx/Footsteps.mp3",
        footstepInterval = 0.35,
        footstepVolume = 0.3,
        damageSoundPath = "assets/audio/sfx/Damage.mp3",
        damageFlashColor = { 1.0, 0.15, 0.15 },
        damageFlashAlpha = 0.35,
        damageFlashDuration = 0.12,
        cellPickupSoundPath = "assets/audio/sfx/Pickup.mp3",
        menuMusicPath = MENU_MUSIC_PATH,
        gameMusicPath = GAME_MUSIC_PATH,
        menuMusicFadeDuration = 1.0,
        gameOverSoundPath = "assets/audio/sfx/Game Over.mp3",
        victorySoundPath = "assets/audio/sfx/Victory.mp3",
        gameOverMusicFadeDuration = 1.0,
        gameOverTextFadeDuration = 1.0,
        transitionDuration = TRANSITION_DURATION,
        fadeDuration = FADE_DURATION,
        selectedLevelIndex = 1,
        levelPresets = {
            {
                id = "level_1",
                label = "Level 1 - Training Deck",
                description = "Lower threat layout for warm-up runs."
            },
            {
                id = "level_2",
                label = "Level 2 - Core Sector",
                description = "Balanced station pressure."
            },
            {
                id = "level_3",
                label = "Level 3 - Reactor Wing",
                description = "Dense patrols with aggressive hunters."
            }
        }
    })

    StateManager.register("menu", MenuState)
    StateManager.register("level_select", LevelSelectState)
    StateManager.register("game", GameState)
    StateManager.register("transition", TransitionState)
    StateManager.register("pause", PauseState)
    StateManager.register("victory", VictoryState)
    StateManager.register("gameover", GameOverState)

    StateManager.change("menu")
end

function love.update(dt)
    -- The active state owns all per-frame gameplay updates.
    StateManager.update(dt)
end

function love.keypressed(key)
    StateManager.keypressed(key)
end

function love.keyreleased(key)
    StateManager.keyreleased(key)
end

function love.mousepressed(x, y, button, istouch, presses)
    StateManager.mousepressed(x, y, button, istouch, presses)
end

function love.draw()
    -- Drawing is delegated to the currently active state.
    StateManager.draw()
end
