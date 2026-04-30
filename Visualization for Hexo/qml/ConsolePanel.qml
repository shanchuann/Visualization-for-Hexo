import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    TextArea {
        anchors.fill: parent
        readOnly: true
        text: appContext ? appContext.logText : ""
        wrapMode: TextEdit.NoWrap
        font.family: "Consolas"
        font.pixelSize: 12
    }
}
