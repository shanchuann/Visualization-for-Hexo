import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    ListView {
        anchors.fill: parent
        model: appContext ? appContext.posts : []
        delegate: Rectangle {
            width: ListView.view.width
            height: 44
            color: index % 2 === 0 ? "#F7F8FC" : "#EEF1F8"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                text: modelData.title || "(untitled)"
                elide: Text.ElideRight
                width: parent.width - 24
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (modelData.path) {
                        appContext.openPost(modelData.path)
                    }
                }
            }
        }
    }
}
