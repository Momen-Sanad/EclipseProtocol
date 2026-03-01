local AudioSystem = require("src/systems/audio_system")
local StateManager = require("src/core/state_manager")
local MenuState = require("src/states/menu")
local GameState = require("src/states/game")
local TransitionState = require("src/states/transition")
local PauseState = require("src/states/pause")
local VictoryState = require("src/states/victory")
local GameOverState = require("src/states/gameover")

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 2
VIRTUAL_HEIGHT = 1

PLAYER_SIZE = 600

local MENU_MUSIC_PATH = "assets/audio/music/StartMenu.mp3"
local GAME_MUSIC_PATH = nil
local TRANSITION_DURATION = 2.5
local FADE_DURATION = 0.5

function love.load()
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, { fullscreen = true })
    love.graphics.setDefaultFilter("linear", "linear", 16)
    love.math.setRandomSeed(os.time())

    AudioSystem.init({
        musicVolume = 0.8,
        sfxVolume = 0.9
    })

    StateManager.init({
        windowWidth = WINDOW_WIDTH,
        windowHeight = WINDOW_HEIGHT,
        backgroundPath = "assets/background.png",
        playerSpritePath = "assets/sprites/player/Robot.png",
        playerSize = PLAYER_SIZE,
        playerSpeed = 300,
        playerFrameDuration = 0.12,
        menuMusicPath = MENU_MUSIC_PATH,
        gameMusicPath = GAME_MUSIC_PATH,
        transitionDuration = TRANSITION_DURATION,
        fadeDuration = FADE_DURATION
    })

    StateManager.register("menu", MenuState)
    StateManager.register("game", GameState)
    StateManager.register("transition", TransitionState)
    StateManager.register("pause", PauseState)
    StateManager.register("victory", VictoryState)
    StateManager.register("gameover", GameOverState)

    StateManager.change("menu")
end

function love.update(dt)
    StateManager.update(dt)
end

function love.keypressed(key)
    StateManager.keypressed(key)
end

function love.keyreleased(key)
    StateManager.keyreleased(key)
end

function love.draw()
    StateManager.draw()
end
