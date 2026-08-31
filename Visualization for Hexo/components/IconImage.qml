import QtQuick 2.15
import QtQuick.Effects

Item {
    id: root
    property url source
    property color color: "#FFFFFF"
    readonly property bool isRaster: String(root.source).toLowerCase().endsWith(".png")

    implicitWidth: 24
    implicitHeight: 24

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectFit
        visible: root.isRaster
    }

    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: root.color
        visible: !root.isRaster
    }
}
