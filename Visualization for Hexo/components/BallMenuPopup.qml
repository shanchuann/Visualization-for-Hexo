import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: root
    width: 184
    height: menuColumn.implicitHeight + 16
    padding: 0
    modal: false
    // Keep the ball itself clickable while the menu is open; outside clicks
    // are intentionally handled by the ball toggle instead of auto-closing.
    closePolicy: Popup.CloseOnEscape

    // Required properties from parent
    property var emotionBall
    property var sidebar
    property var settingsDrawer
    property var pluginDrawer
    property var editorContent
    property var appContext
    property int fixedSidebarWidth
    readonly property string iconBase: "qrc:/qt/qml/visualization for hexo/assets/iconpark/"

    // Signals for actions
    signal aiEditRequested()
    signal newArticleRequested()
    signal viewModeToggleRequested(bool isMarkdown)

    property bool isActuallyOpened: false
    property string positionSide: "left"

    // Keep the menu in overlay coordinates. EmotionBall is a child of the
    // window while this popup is a child of Overlay.overlay.
    function reposition() {
        if (!emotionBall || !parent) return
        var p = emotionBall.mapToItem(parent, 0, 0)
        var gap = 14
        var margin = 12
        var leftX = p.x - width - gap
        var rightX = p.x + emotionBall.width + gap
        var canLeft = leftX >= margin
        var canRight = rightX + width <= parent.width - margin
        var preferLeft = p.x + emotionBall.width / 2 > parent.width / 2
        var useLeft = preferLeft ? (canLeft || !canRight) : (!canRight && canLeft)

        if (useLeft) {
            x = leftX
            positionSide = "left"
        } else {
            x = rightX
            positionSide = "right"
        }
        if (!canLeft && !canRight) {
            x = Math.max(margin, Math.min(parent.width - width - margin, x))
        }

        var centeredY = p.y + (emotionBall.height - height) / 2
        var maxY = Math.max(margin, parent.height - height - margin)
        y = Math.max(margin, Math.min(maxY, centeredY))
    }

    // The list is data-driven so the menu remains coupled to the ball's
    // available actions while labels react to current editor state.
    readonly property var menuItems: [
        { kind: "newArticle", label: "新建文章", icon: "plus.png" },
        { kind: "sidebar", label: "", icon: "menu.png" },
        { kind: "settings", label: "设置", icon: "setting.png" },
        { kind: "plugins", label: "插件管理", icon: "plug.png" },
        { kind: "view", label: "", icon: "" },
        { kind: "ai", label: "AI 编辑", icon: "ai-magic.png" }
    ]

    background: Rectangle {
        color: "transparent"
    }

    contentItem: Column {
        id: menuColumn
        spacing: 8
        topPadding: 8
        bottomPadding: 8
        leftPadding: 8
        rightPadding: 8

        Repeater {
            model: root.menuItems
            delegate: MenuButton {
                required property var modelData
                property string kind: modelData.kind
                text: kind === "sidebar"
                    ? (sidebar.visible ? "隐藏侧边栏" : "显示侧边栏")
                    : kind === "view"
                        ? (editorContent.isMarkdown ? "代码模式" : "预览模式")
                    : modelData.label
                iconSource: root.iconBase + (kind === "view"
                    ? (editorContent.isMarkdown ? "code.png" : "preview-open.png")
                    : modelData.icon)
                onClicked: {
                    if (kind === "newArticle") {
                        root.newArticleRequested()
                    } else if (kind === "sidebar") {
                        sidebar.visible = !sidebar.visible
                        var pane = sidebar.parent
                        pane.SplitView.preferredWidth = sidebar.visible ? fixedSidebarWidth : 0
                        pane.SplitView.minimumWidth = sidebar.visible ? fixedSidebarWidth : 0
                        pane.SplitView.maximumWidth = sidebar.visible ? fixedSidebarWidth : 0
                    } else if (kind === "settings") {
                        settingsDrawer.open()
                    } else if (kind === "plugins") {
                        pluginDrawer.open()
                    } else if (kind === "view") {
                        viewModeToggleRequested(!editorContent.isMarkdown)
                    } else if (kind === "ai") {
                        aiEditRequested()
                    }
                    root.close()
                }
            }
        }
    }

    onOpened: {
        isActuallyOpened = true
        reposition()
        if (emotionBall && !emotionBall.aiActive) emotionBall.celebrate()
    }

    onClosed: {
        isActuallyOpened = false
        if (emotionBall && !emotionBall.aiActive && !emotionBall.idleTouring) emotionBall.setEmotion("02")
    }

    Connections {
        target: emotionBall
        function onXChanged() { if (root.opened) root.reposition() }
        function onYChanged() { if (root.opened) root.reposition() }
        function onWidthChanged() { if (root.opened) root.reposition() }
        function onHeightChanged() { if (root.opened) root.reposition() }
    }

    Connections {
        target: root.parent
        function onWidthChanged() { if (root.opened) root.reposition() }
        function onHeightChanged() { if (root.opened) root.reposition() }
    }

    // Menu button component
    component MenuButton: Button {
        id: btn
        property string iconSource: ""
        width: 168
        height: 42
        flat: true
        hoverEnabled: true

        background: Rectangle {
            radius: 22
            color: btn.down ? Qt.rgba(216, 226, 255, 0.96)
                : (btn.hovered ? Qt.rgba(248, 250, 255, 0.94) : Qt.rgba(248, 250, 255, 0.78))
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.86)
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        contentItem: Row {
            spacing: 10
            leftPadding: 12

            Image {
                source: btn.iconSource
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
            }

            Text {
                text: btn.text
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#253044"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
