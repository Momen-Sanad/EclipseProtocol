-- Game-over screen showing final run stats over the failure artwork.
local RunResultScreen = require("src/ui/run_result_screen")

return RunResultScreen.new({
    result = "gameover",
    backgroundPath = "assets/ui/Game Over.jpeg",
    musicContextKey = "gameOverSoundPath",
    defaultMusicPath = "assets/audio/sfx/Game Over.mp3",
    actionLabel = "RETRY",
    valueFontSize = 42,
    scoreFontSize = 42,
    actionFontSize = 40,
    valueColor = { 1.0, 0.72, 0.68, 1.0 },
    valueShadow = { 0.24, 0.04, 0.04, 0.95 },
    actionColor = { 0.98, 0.72, 0.68, 0.95 },
    actionShadow = { 0.18, 0.03, 0.03, 0.95 },
    timeValueRect = { x = 176, y = 618, w = 268, h = 20 },
    scoreValueRect = { x = 495, y = 612, w = 265, h = 25 },
    cellsValueRect = { x = 804, y = 618, w = 278, h = 30 },
    actionRect = { x = 975, y = 734, w = 238, h = 90 }
})
