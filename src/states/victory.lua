-- Victory screen showing final run stats over the completion artwork.
local RunResultScreen = require("src/ui/run_result_screen")

return RunResultScreen.new({
    result = "victory",
    backgroundPath = "assets/ui/Victory.jpg",
    musicContextKey = "victorySoundPath",
    defaultMusicPath = "assets/audio/sfx/Victory.mp3",
    actionLabel = "PLAY AGAIN",
    valueFontSize = 42,
    scoreFontSize = 42,
    actionFontSize = 40,
    valueColor = { 0.88, 1.0, 0.96, 1.0 },
    valueShadow = { 0.02, 0.16, 0.16, 0.95 },
    actionColor = { 0.78, 0.96, 0.92, 0.95 },
    actionShadow = { 0.02, 0.12, 0.12, 0.95 },
    timeValueRect = { x = 176, y = 618, w = 268, h = 25 },
    scoreValueRect = { x = 495, y = 612, w = 260, h = 25 },
    cellsValueRect = { x = 804, y = 618, w = 278, h = 25 },
    actionRect = { x = 975, y = 734, w = 238, h = 82 }
})
