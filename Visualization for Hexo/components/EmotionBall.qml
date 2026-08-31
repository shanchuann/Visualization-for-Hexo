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

    signal ballClicked()
    signal positionChanged()

    onXChanged: positionChanged()
    onYChanged: positionChanged()

    width: ballSize
    height: ballSize

    function setEmotion(id) { ballWeb.runJavaScript("window.ballSetEmotion && window.ballSetEmotion('" + id + "')") }
    function celebrate() { ballWeb.runJavaScript("window.ballCelebrate && window.ballCelebrate()") }
    function wake() { ballWeb.runJavaScript("window.ballWake && window.ballWake()") }
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

        if (dist > 50) { // Only change emotion if mouse is far enough
            if (angle >= -22.5 && angle < 22.5) emotionId = "03" // right
            else if (angle >= 22.5 && angle < 67.5) emotionId = "04" // down-right
            else if (angle >= 67.5 && angle < 112.5) emotionId = "05" // down
            else if (angle >= 112.5 && angle < 157.5) emotionId = "06" // down-left
            else if (angle >= 157.5 || angle < -157.5) emotionId = "07" // left
            else if (angle >= -157.5 && angle < -112.5) emotionId = "08" // up-left
            else if (angle >= -112.5 && angle < -67.5) emotionId = "09" // up
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
                // The first visible state is a short shake-awake sequence;
                // the web engine settles back to the normal idle emotion.
                root.wake()
            }
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
