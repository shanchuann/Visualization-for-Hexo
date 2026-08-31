import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine

Item {
    id: root

    readonly property int ballSize: 104
    readonly property string iconBase: "qrc:/qt/qml/visualization for hexo/assets/iconpark/"
    property bool isMarkdownView: true

    // Menu metrics (5 capsules × 42px + 4 × 8px spacing)
    readonly property int capsuleH: 42
    readonly property int capsuleGap: 8
    readonly property int capsuleCount: 5
    readonly property int menuH: capsuleCount * capsuleH + (capsuleCount - 1) * capsuleGap
    readonly property int menuW: 172
    readonly property int edgeGap: 10

    property real ratioX: 1.0
    property real ratioY: 1.0
    property bool positionInitialized: false
    property bool aiActive: false
    property string aiState: "idle"
    property bool wakeCompleted: false
    property bool wakeStarted: false
    property bool idleTouring: false

    readonly property var idleEmotionIds: ["02", "03", "04", "10", "11", "15", "19", "20"]

    signal ballClicked()
    signal positionChanged()

    onXChanged: positionChanged()
    onYChanged: positionChanged()

    width: ballSize
    height: ballSize

    function setEmotion(id) { ballWeb.runJavaScript("window.ballSetEmotion && window.ballSetEmotion('" + id + "')") }
    function celebrate() { ballWeb.runJavaScript("window.ballCelebrate && window.ballCelebrate()") }
    function wake() { ballWeb.runJavaScript("window.ballWake && window.ballWake()") }
    function startIdleTour() {
        if (root.aiActive || !root.wakeCompleted) return
        root.idleTouring = true
        ballWeb.runJavaScript("window.ballStartRandomTour && window.ballStartRandomTour(" + JSON.stringify(root.idleEmotionIds) + ", 7200)")
    }
    function stopIdleTour() {
        root.idleTouring = false
        ballWeb.runJavaScript("window.ballStopTour && window.ballStopTour()")
    }
    function setAiState(state) {
        var ids = {
            receiving: "31",
            thinking: "30",
            replying: "39",
            done: "33",
            error: "34",
            waiting: "35",
            searching: "40",
            idle: "02"
        }
        if (state === "idle") {
            root.aiState = "idle"
            aiSettleTimer.stop()
            root.aiActive = false
            root.setEmotion(ids.idle)
            Qt.callLater(root.startIdleTour)
            return
        }
        if (root.aiState === state && state !== "done" && state !== "error") return
        root.aiState = state
        root.aiActive = true
        root.stopIdleTour()
        root.setEmotion(ids[state] || ids.thinking)
        if (state === "done" || state === "error") aiSettleTimer.restart()
    }
    function surprised() { ballWeb.runJavaScript("window.ballSurprised && window.ballSurprised()") }
    function spin() { ballWeb.runJavaScript("window.ballSpin && window.ballSpin()") }

    // Update ball's eye direction based on mouse position
    function updateEyeTarget(mouseX, mouseY) {
        var ballCenterX = root.x + root.width / 2
        var ballCenterY = root.y + root.height / 2
        var dx = mouseX - ballCenterX
        var dy = mouseY - ballCenterY
        var angle = Math.atan2(dy, dx) * 180 / Math.PI

        // Map angle to emotion IDs (simple 8-direction mapping)
        var emotionId = "02" // default (center)
        var dist = Math.sqrt(dx * dx + dy * dy)

        if (root.idleTouring) {
            ballWeb.runJavaScript("window.ballSetGaze && window.ballSetGaze(" + (dx / 180).toFixed(3) + "," + (dy / 140).toFixed(3) + ")")
            return
        }

        if (dist > 50) { // Only change emotion if mouse is far enough
            if (angle >= -22.5 && angle < 22.5) emotionId = "03" // right
            else if (angle >= 22.5 && angle < 67.5) emotionId = "04" // down-right
            else if (angle >= 67.5 && angle < 112.5) emotionId = "05" // down
            else if (angle >= 112.5 && angle < 157.5) emotionId = "06" // down-left
            else if (angle >= 157.5 || angle < -157.5) emotionId = "07" // left
            else if (angle >= -157.5 && angle < -112.5) emotionId = "11" // up-left / puzzled
            else if (angle >= -112.5 && angle < -67.5) emotionId = "03" // up / curious
            else if (angle >= -67.5 && angle < -22.5) emotionId = "10" // up-right
        }

        setEmotion(emotionId)
    }

    WebEngineView {
        id: ballWeb
        anchors.fill: parent
        url: "qrc:/ball/index.html"
        backgroundColor: "transparent"

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                // Play the one-time waking sequence, then begin quiet idle motion.
                if (!root.wakeStarted) {
                    root.wakeStarted = true
                    root.wake()
                    wakeTimer.restart()
                }
            }
        }
    }

    Timer {
        id: wakeTimer
        interval: 2600
        repeat: false
        onTriggered: {
            root.wakeCompleted = true
            root.startIdleTour()
        }
    }

    Timer {
        id: aiSettleTimer
        interval: 2400
        repeat: false
        onTriggered: {
            root.aiActive = false
            root.setEmotion("02")
            root.startIdleTour()
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 0
        drag.maximumX: root.parent ? root.parent.width - root.width : 0
        drag.minimumY: 0
        drag.maximumY: root.parent ? root.parent.height - root.height : 0

        onClicked: {
            if (!drag.active) {
                root.ballClicked()
            }
        }
    }
}
