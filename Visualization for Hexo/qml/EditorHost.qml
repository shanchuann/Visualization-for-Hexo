import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine
import QtWebChannel

Item {
    id: root
    property string content: ""
    property bool loadingPage: false
    property string editorHtmlPath: "qrc:/qt/qml/visualization for hexo/web/markdown-editor/index.html"

    WebChannel {
        id: bridgeChannel
        registeredObjects: [editorBridge]
    }

    Rectangle {
        anchors.fill: parent
        color: "#F6F7FB"
        border.width: 1
        border.color: "#D2D7E3"
        radius: 10

        WebEngineView {
            id: webEditor
            anchors.fill: parent
            anchors.margins: 1
            url: root.editorHtmlPath
            webChannel: bridgeChannel

            onLoadingChanged: function(loadRequest) {
                root.loadingPage = loadRequest.status === WebEngineLoadRequest.LoadStartedStatus
                if (loadRequest.status === WebEngineLoadRequest.LoadSucceededStatus) {
                    webEditor.runJavaScript("window.HexoBridge && window.HexoBridge.setContent(" + JSON.stringify(root.content || "") + ");")
                }
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: root.loadingPage
            visible: root.loadingPage
        }
    }

    Connections {
        target: editorBridge
        function onContentChanged() {
            root.content = editorBridge.content
            if (!root.loadingPage) {
                webEditor.runJavaScript("window.HexoBridge && window.HexoBridge.setContent(" + JSON.stringify(root.content || "") + ");")
            }
        }
    }
}
