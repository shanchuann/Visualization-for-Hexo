import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property bool expanded: false
    property bool hasOpenedPost: false
    property bool settingsDrawerOpen: false
    property bool pluginDrawerOpen: false
    property bool sidebarVisible: true
    property bool isMarkdownView: true
    readonly property string iconBase: "qrc:/qt/qml/visualization for hexo/assets/iconpark/"

    // Theme tokens (match project style)
    property color md3Primary: "#1B6EF3"
    property color md3PrimaryContainer: "#D8E2FF"
    property color md3OnPrimaryContainer: "#001A41"
    property color md3OnSurfaceVariant: "#44474E"

    signal addArticleRequested()
    signal aiEditRequested()
    signal pluginManagementRequested()
    signal sidebarToggleRequested()
    signal viewModeToggleRequested()

    visible: !settingsDrawerOpen && !pluginDrawerOpen
    width: 80
    height: expanded ? 420 : 72
    z: 5

    function collapse() { expanded = false }

    // Shared tooltip background component
    component StyledTip: ToolTip {
        id: styledTip
        delay: 120
        timeout: 2200
        contentItem: Text {
            text: styledTip.text
            color: root.md3OnPrimaryContainer
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        background: Rectangle {
            radius: 10
            color: Qt.rgba(root.md3PrimaryContainer.r, root.md3PrimaryContainer.g, root.md3PrimaryContainer.b, 0.96)
            border.width: 1
            border.color: Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, 0.35)
        }
    }

    // Click-outside catcher
    MouseArea {
        id: outsideCatcher
        anchors.fill: parent
        enabled: root.expanded
        anchors.leftMargin: -2000
        anchors.topMargin: -2000
        anchors.rightMargin: -2000
        anchors.bottomMargin: -2000
        z: -1
        onClicked: root.collapse()
    }

    // Sub-FAB: Plugin Management (topmost)
    Rectangle {
        id: pluginFab
        anchors.horizontalCenter: mainFab.horizontalCenter
        width: 44
        height: 44
        radius: 22
        color: root.md3Primary
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)
        visible: root.expanded
        scale: root.expanded ? 1 : 0
        opacity: root.expanded ? 1 : 0
        y: mainFab.y - 180

        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            anchors.topMargin: 2
            z: -1
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.10)
        }

        IconImage {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: root.iconBase + "plug.png"
            color: "#FFFFFF"
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "#FFFFFF"
            opacity: pluginFabMouse.containsMouse ? 0.18 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: pluginFabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.collapse()
                root.pluginManagementRequested()
            }
        }

        StyledTip {
            visible: pluginFabMouse.containsMouse
            text: "插件管理"
        }
    }

    // Sub-FAB: AI Edit (topmost when expanded)
    Rectangle {
        id: aiFab
        anchors.horizontalCenter: mainFab.horizontalCenter
        width: 44
        height: 44
        radius: 22
        color: root.md3Primary
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)
        visible: root.expanded
        scale: root.expanded ? 1 : 0
        opacity: root.expanded ? 1 : 0
        y: mainFab.y - 120

        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }


        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            anchors.topMargin: 2
            z: -1
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.10)
        }

        IconImage {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: root.iconBase + "ai-magic.png"
            color: "#FFFFFF"
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "#FFFFFF"
            opacity: aiFabMouse.containsMouse && root.hasOpenedPost ? 0.18 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: aiFabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.hasOpenedPost ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: {
                if (root.hasOpenedPost) {
                    root.collapse()
                    root.aiEditRequested()
                }
            }
        }

        StyledTip {
            visible: aiFabMouse.containsMouse
            text: root.hasOpenedPost ? "AI 编辑" : "请先打开一篇文章"
        }
    }

    // Sub-FAB: Add Article
    Rectangle {
        id: addArticleFab
        anchors.horizontalCenter: mainFab.horizontalCenter
        width: 44
        height: 44
        radius: 22
        color: root.md3Primary
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)
        visible: root.expanded
        scale: root.expanded ? 1 : 0
        opacity: root.expanded ? 1 : 0
        y: mainFab.y - 60

        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }


        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            anchors.topMargin: 2
            z: -1
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.10)
        }

        IconImage {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: root.iconBase + "plus.png"
            color: "#FFFFFF"
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "#FFFFFF"
            opacity: addArticleMouse.containsMouse ? 0.18 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: addArticleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.collapse()
                root.addArticleRequested()
            }
        }

        StyledTip {
            visible: addArticleMouse.containsMouse
            text: "新增文章"
        }
    }

    // Sub-FAB: View Mode (source / preview)
    Rectangle {
        id: viewModeFab
        anchors.horizontalCenter: mainFab.horizontalCenter
        width: 44
        height: 44
        radius: 22
        color: root.md3Primary
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)
        visible: root.expanded
        scale: root.expanded ? 1 : 0
        opacity: root.expanded ? 1 : 0
        y: mainFab.y - 240

        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            anchors.topMargin: 2
            z: -1
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.10)
        }

        IconImage {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: root.iconBase + (root.isMarkdownView ? "code.png" : "preview-open.png")
            color: "#FFFFFF"
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "#FFFFFF"
            opacity: viewModeMouse.containsMouse ? 0.18 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: viewModeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.collapse()
                root.viewModeToggleRequested()
            }
        }

        StyledTip {
            visible: viewModeMouse.containsMouse
            text: root.isMarkdownView ? "切换到源码" : "切换到预览"
        }
    }

    // Sub-FAB: Sidebar toggle
    Rectangle {
        id: sidebarFab
        anchors.horizontalCenter: mainFab.horizontalCenter
        width: 44
        height: 44
        radius: 22
        color: root.md3Primary
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)
        visible: root.expanded
        scale: root.expanded ? 1 : 0
        opacity: root.expanded ? 1 : 0
        y: mainFab.y - 300

        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            anchors.topMargin: 2
            z: -1
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.10)
        }

        IconImage {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: root.iconBase + "MeteorIconsSidebar.png"
            color: "#FFFFFF"
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "#FFFFFF"
            opacity: sidebarFabMouse.containsMouse ? 0.18 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: sidebarFabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.collapse()
                root.sidebarToggleRequested()
            }
        }

        StyledTip {
            visible: sidebarFabMouse.containsMouse
            text: root.sidebarVisible ? "收起侧边栏" : "展开侧边栏"
        }
    }

    // Main FAB
    Rectangle {
        id: mainFab
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 6
        anchors.bottomMargin: 6
        width: 54
        height: 54
        radius: 27
        color: root.md3Primary
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            anchors.topMargin: 2
            z: -1
            radius: 27
            color: Qt.rgba(0, 0, 0, 0.15)
        }

        IconImage {
            id: fabIcon
            anchors.centerIn: parent
            width: 22
            height: 22
            source: root.expanded ? (root.iconBase + "close-white.png") : (root.iconBase + "IconParkOutlineToolkit.png")
            color: "#FFFFFF"
            opacity: 1
            Behavior on source {
                SequentialAnimation {
                    NumberAnimation { target: fabIcon; property: "opacity"; to: 0; duration: 100 }
                    PropertyAction { target: fabIcon; property: "source" }
                    NumberAnimation { target: fabIcon; property: "opacity"; to: 1; duration: 100 }
                }
            }
        }

        MouseArea {
            id: mainFabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        Rectangle {
            anchors.fill: parent
            radius: 27
            color: "#FFFFFF"
            opacity: mainFabMouse.pressed ? 0.18 : (mainFabMouse.containsMouse ? 0.10 : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.expanded
        onActivated: root.collapse()
    }
}
