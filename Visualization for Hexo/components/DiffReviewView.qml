import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Flickable {
    id: root
    contentWidth: width
    contentHeight: contentCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    property var pendingDiff: null       // { hunks, proposed, original }
    property var hunkDecisions: ({})     // hunkId → bool
    readonly property string iconBase: "qrc:/qt/qml/visualization for hexo/assets/iconpark/"

    property color md3OnSurface: "#1A1B20"
    property color md3OnSurfaceVariant: "#44474E"
    property color md3Primary: "#1B6EF3"
    property color md3OnPrimary: "#FFFFFF"
    property color md3PrimaryContainer: "#D8E2FF"
    property color md3OnPrimaryContainer: "#001A41"
    property color md3OutlineVariant: "#C4C6D0"
    property color md3Error: "#BA1A1A"
    property color md3SurfaceContainer: "#EDEEF4"
    property int shapeMedium: 12

    signal hunkDecisionChanged(int hunkId, bool accepted)

    Column {
        id: contentCol
        width: parent.width
        topPadding: 8
        bottomPadding: 24
        spacing: 0

        Repeater {
            model: root.pendingDiff ? root.pendingDiff.hunks : []

            delegate: Column {
                width: contentCol.width
                property var hunk: modelData
                property bool isChange: hunk.type !== "equal"
                property bool isDecided: root.hunkDecisions[hunk.hunkId] !== undefined
                property bool isAccepted: root.hunkDecisions[hunk.hunkId] === true

                // Equal hunk: plain text lines
                Column {
                    width: parent.width
                    visible: !isChange

                    Repeater {
                        model: hunk.origLines || []
                        delegate: TextEdit {
                            width: parent.width
                            text: modelData
                            font.pixelSize: 14
                            color: root.md3OnSurface
                            wrapMode: TextEdit.Wrap
                            readOnly: true
                            selectByMouse: true
                            topPadding: 2
                            bottomPadding: 2
                            leftPadding: 4
                        }
                    }
                }

                // Change hunk: highlighted with accept/reject
                Rectangle {
                    width: parent.width
                    height: visible ? changeCol.implicitHeight + 12 : 0
                    visible: isChange
                    radius: 6
                    color: {
                        if (isDecided && isAccepted) return Qt.rgba(0.12, 0.56, 0.24, 0.06)
                        if (isDecided && !isAccepted) return Qt.rgba(0.73, 0.10, 0.10, 0.04)
                        return Qt.rgba(0.106, 0.431, 0.953, 0.05)
                    }
                    border.width: 1
                    border.color: {
                        if (isDecided && isAccepted) return Qt.rgba(0.12, 0.56, 0.24, 0.25)
                        if (isDecided && !isAccepted) return Qt.rgba(0.73, 0.10, 0.10, 0.2)
                        return Qt.rgba(0.106, 0.431, 0.953, 0.15)
                    }

                    Column {
                        id: changeCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        anchors.topMargin: 6
                        spacing: 2

                        // Original lines (deleted)
                        Column {
                            width: parent.width
                            visible: hunk.type === "replace" || hunk.type === "delete"
                            spacing: 1

                            Repeater {
                                model: hunk.origLines || []
                                delegate: Rectangle {
                                    width: parent.width
                                    height: origText.implicitHeight + 6
                                    radius: 4
                                    color: Qt.rgba(0.73, 0.10, 0.10, 0.08)

                                    TextEdit {
                                        id: origText
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        font.pixelSize: 13
                                        color: isDecided ? Qt.rgba(0.73, 0.10, 0.10, 0.5) : root.md3Error
                                        font.strikeout: true
                                        wrapMode: TextEdit.Wrap
                                        readOnly: true
                                        selectByMouse: true
                                    }
                                }
                            }
                        }

                        // Proposed lines (inserted)
                        Column {
                            width: parent.width
                            visible: hunk.type === "replace" || hunk.type === "insert"
                            spacing: 1

                            Repeater {
                                model: hunk.propLines || []
                                delegate: Rectangle {
                                    width: parent.width
                                    height: propText.implicitHeight + 6
                                    radius: 4
                                    color: isDecided && !isAccepted
                                        ? Qt.rgba(0, 0, 0, 0.02)
                                        : Qt.rgba(0.12, 0.56, 0.24, 0.06)

                                    TextEdit {
                                        id: propText
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        font.pixelSize: 13
                                        color: isDecided && !isAccepted
                                            ? Qt.rgba(0, 0, 0, 0.2)
                                            : "#0F5C2C"
                                        wrapMode: TextEdit.Wrap
                                        readOnly: true
                                        selectByMouse: true
                                    }
                                }
                            }
                        }

                        // Decision buttons row
                        Row {
                            anchors.right: parent.right
                            spacing: 4
                            topPadding: 4
                            bottomPadding: 2

                            // Accept button (check icon)
                            Rectangle {
                                width: 28; height: 24; radius: 12
                                color: isAccepted ? Qt.rgba(0.12, 0.56, 0.24, 0.15) : "transparent"
                                border.width: isAccepted ? 0 : 1
                                border.color: root.md3OutlineVariant

                                IconImage {
                                    anchors.centerIn: parent
                                    source: root.iconBase + "check.png"
                                    width: 14; height: 14
                                    color: isAccepted ? "#0F5C2C" : root.md3OnSurfaceVariant
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.hunkDecisionChanged(hunk.hunkId, true)
                                }
                            }

                            // Reject button (close icon)
                            Rectangle {
                                width: 28; height: 24; radius: 12
                                color: (isDecided && !isAccepted) ? Qt.rgba(0.73, 0.10, 0.10, 0.10) : "transparent"
                                border.width: (isDecided && !isAccepted) ? 0 : 1
                                border.color: root.md3OutlineVariant

                                IconImage {
                                    anchors.centerIn: parent
                                    source: root.iconBase + "close.png"
                                    width: 14; height: 14
                                    color: (isDecided && !isAccepted) ? root.md3Error : root.md3OnSurfaceVariant
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.hunkDecisionChanged(hunk.hunkId, false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
