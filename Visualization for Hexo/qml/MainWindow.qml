import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    property alias postList: postList
    property alias editorHost: editorHost
    property alias consolePanel: consolePanel

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        PostList {
            id: postList
            Layout.fillWidth: true
            Layout.preferredHeight: 260
        }

        EditorHost {
            id: editorHost
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        ConsolePanel {
            id: consolePanel
            Layout.fillWidth: true
            Layout.preferredHeight: 160
        }
    }
}
