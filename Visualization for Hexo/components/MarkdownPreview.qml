import QtQuick 2.15
import QtWebEngine

Item {
    id: root
    property string markdownText: ""
    property int bodyFontSize: 17
    property real lineSpacing: 1.8
    property string previewHtmlPath: (appContext && appContext.previewRuntimeUrl && appContext.previewRuntimeUrl.length > 0)
                                     ? appContext.previewRuntimeUrl
                                     : "qrc:/preview/index.html"
    property string previewPageHtml: (appContext && appContext.previewPageHtml && appContext.previewPageHtml.length > 0)
                                     ? appContext.previewPageHtml
                                     : ""
    property bool pageReady: false
    property bool loadFailed: false
    property bool bridgeActive: false
    property string loadError: ""
    property int estimatedHeight: 520
    property int loadRetryCount: 0
    readonly property int maxLoadRetryCount: 3
    property bool hasStarted: false
    property string lastPushedMarkdown: ""
    property int lastPushedFontPx: -1
    property real lastPushedLineSpacing: -1
    implicitHeight: estimatedHeight
    signal scrollRequested(int deltaY)

    function estimateHeight() {
        var lineCount = (root.markdownText || "").split("\n").length
        return Math.max(520, (lineCount + 8) * 24)
    }

    function clearRenderedCache() {
        root.lastPushedMarkdown = ""
        root.lastPushedFontPx = -1
        root.lastPushedLineSpacing = -1
    }

    function pushMarkdown() {
        if (!root.pageReady || root.loadFailed) {
            return
        }
        const source = root.markdownText || ""
        if (appContext && appContext.appendStructuredLog) {
            try {
                appContext.appendStructuredLog("debug", "PREVIEW_PUSH", "len=" + source.length + " pageReady=" + root.pageReady + " bridgeActive=" + root.bridgeActive)
            } catch (e) {
                // ignore
            }
        }
        const fontPx = Math.max(12, Math.min(36, root.bodyFontSize))
        const lineHeight = Math.max(1.2, Math.min(2.6, root.lineSpacing))
        if (source === root.lastPushedMarkdown
            && fontPx === root.lastPushedFontPx
            && Math.abs(lineHeight - root.lastPushedLineSpacing) < 0.001) {
            return
        }

        root.lastPushedMarkdown = source
        root.lastPushedFontPx = fontPx
        root.lastPushedLineSpacing = lineHeight

        const payload = JSON.stringify(source)
        // Also log the payload length into the page console so DevTools can capture it
        const js = "(function(){ var p = " + payload + "; try{ console.log('[HexoBridge] PUSH payload_len=' + (p && p.length ? p.length : 0)); }catch(e){} var cssId='__hexo_hide_scrollbar__'; if(!document.getElementById(cssId)){ try{ var s=document.createElement('style'); s.id=cssId; s.textContent='html,body{height:auto;margin:0;padding:0;overflow:hidden;min-height:auto;} body{scrollbar-width:none;-ms-overflow-style:none;} body::-webkit-scrollbar{width:0;height:0;background:transparent;}'; document.head.appendChild(s);}catch(_){/* ignore */} } if(typeof window.updateMarkdown === 'function'){ window.updateMarkdown(p, { bodyFontSize: " + fontPx + ", lineSpacing: " + lineHeight + " }); return true; } return false; })();"
        previewWeb.runJavaScript(js, function(ok) {
            root.bridgeActive = !!ok
            if (ok) {
                heightProbeTimer.restart()
                delayedHeightProbeTimer.restart()
            }
        })
    }

    function restartPreviewEngine() {
        root.pageReady = false
        root.loadFailed = false
        root.bridgeActive = false
        root.loadError = ""
        root.clearRenderedCache()
        if (root.previewPageHtml.length > 0) {
            var base = root.previewHtmlPath || "";
            try {
                if (!base.endsWith("index.html")) {
                    if (base.endsWith("/")) {
                        base = base + "index.html";
                    } else {
                        base = base + "/index.html";
                    }
                }
            } catch (e) {
                // ignore
            }
            previewWeb.loadHtml(root.previewPageHtml, base)
        } else {
            const target = root.previewHtmlPath || ""
            if (previewWeb.url && previewWeb.url.toString() === target) {
                previewWeb.reload()
            } else {
                previewWeb.url = target
            }
        }
        startupGuard.restart()
    }

    function failLoad(message) {
        root.pageReady = false
        root.loadFailed = true
        root.loadError = message
        root.bridgeActive = false
        if (appContext && appContext.appendStructuredLog) {
            try {
                appContext.appendStructuredLog("error", "PREVIEW_LOAD_FAIL", "message=" + message + " url=" + root.previewHtmlPath)
            } catch (e) {
                // ignore logging errors
            }
        }
        startupGuard.stop()
    }

    onMarkdownTextChanged: {
        estimatedHeight = estimateHeight()
        renderDebounce.restart()
    }
    onPreviewHtmlPathChanged: {
        if (hasStarted && previewHtmlPath && previewHtmlPath.length > 0) {
            restartPreviewEngine()
        }
    }
    onPreviewPageHtmlChanged: {
        if (hasStarted) {
            restartPreviewEngine()
        }
    }
    onBodyFontSizeChanged: renderDebounce.restart()
    onLineSpacingChanged: renderDebounce.restart()

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#FFFFFF"
        border.width: 1
        border.color: "#D8DEE4"
        clip: true

        WebEngineView {
            id: previewWeb
            anchors.fill: parent
            url: "about:blank"
            settings.javascriptEnabled: true
            settings.localContentCanAccessRemoteUrls: false
            settings.localContentCanAccessFileUrls: true
            settings.errorPageEnabled: true

            onLoadingChanged: function(loadRequest) {
                if (appContext && appContext.appendStructuredLog) {
                    appContext.appendStructuredLog("info", "PREVIEW_WEB_LOAD",
                                                  "status=" + loadRequest.status
                                                  + " url=" + loadRequest.url
                                                  + " code=" + (loadRequest.errorCode !== undefined ? loadRequest.errorCode : "")
                                                  + " domain=" + (loadRequest.errorDomain !== undefined ? loadRequest.errorDomain : "")
                                                  + " error=" + (loadRequest.errorString || ""))
                }
                var LoadStarted = (typeof WebEngineLoadRequest !== 'undefined') ? WebEngineLoadRequest.LoadStartedStatus : 1
                var LoadSucceeded = (typeof WebEngineLoadRequest !== 'undefined') ? WebEngineLoadRequest.LoadSucceededStatus : 2
                var LoadFailed = (typeof WebEngineLoadRequest !== 'undefined') ? WebEngineLoadRequest.LoadFailedStatus : 3

                if (loadRequest.status === LoadStarted) {
                    startupGuard.restart()
                    return
                }
                if (loadRequest.status === LoadSucceeded) {
                    root.pageReady = true
                    root.loadFailed = false
                    root.loadError = ""
                    root.loadRetryCount = 0
                    root.clearRenderedCache()
                    startupGuard.stop()
                    runtimeProbe.restart()
                    return
                }
                if (loadRequest.status === LoadFailed) {
                    if (root.loadRetryCount < root.maxLoadRetryCount) {
                        root.loadRetryCount += 1
                        retryTimer.restart()
                        return
                    }
                    root.failLoad(loadRequest.errorString || "Markdown 预览页面加载失败")
                }
            }

            onNavigationRequested: function(request) {
                if (request.navigationType === WebEngineNavigationRequest.NavigationTypeLinkClicked
                    && !request.url.toString().startsWith("qrc:/")) {
                    Qt.openUrlExternally(request.url)
                    request.action = WebEngineNavigationRequest.IgnoreRequest
                }
            }

            onRenderProcessTerminated: function(terminationStatus, exitCode) {
                root.failLoad("渲染进程异常退出（status=" + terminationStatus + ", exitCode=" + exitCode + "）")
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.pageReady || root.loadFailed
            color: "#FFFFFF"

            Column {
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 48, 520)
                spacing: 10

                Text {
                    width: parent.width
                    text: root.loadFailed ? "升级版 Markdown 预览暂时不可用" : "升级版 Markdown 预览加载中..."
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#1f2328"
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: root.loadFailed ? root.loadError : "正在启动 VSCode 风格渲染引擎"
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    color: "#57606a"
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    visible: root.loadFailed
                    width: 120
                    height: 34
                    radius: 17
                    color: "#1B6EF3"
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "重新加载"
                        color: "#FFFFFF"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.restartPreviewEngine()
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: false
            onWheel: (wheel) => {
                if (Math.abs(wheel.angleDelta.y) > Math.abs(wheel.angleDelta.x)) {
                    root.scrollRequested(wheel.angleDelta.y)
                    wheel.accepted = true
                } else {
                    wheel.accepted = false
                }
            }
        }
    }

    Timer {
        id: renderDebounce
        interval: 100
        repeat: false
        onTriggered: root.pushMarkdown()
    }

    Timer {
        id: retryTimer
        interval: 320
        repeat: false
        onTriggered: root.restartPreviewEngine()
    }

    Timer {
        id: heightProbeTimer
        interval: 80
        repeat: false
        onTriggered: {
            previewWeb.runJavaScript(
                "(function(){ return Math.max(document.documentElement.scrollHeight || 0, document.body.scrollHeight || 0); })();",
                function(h) {
                    if (h && h > 0) {
                        root.estimatedHeight = Math.max(520, h + 24)
                    }
                })
        }
    }

    Timer {
        id: delayedHeightProbeTimer
        interval: 600
        repeat: false
        onTriggered: {
            previewWeb.runJavaScript(
                "(function(){ return Math.max(document.documentElement.scrollHeight || 0, document.body.scrollHeight || 0); })();",
                function(h) {
                    if (h && h > 0) {
                        root.estimatedHeight = Math.max(520, h + 24)
                    }
                })
        }
    }

    Timer {
        id: runtimeProbe
        interval: 1500
        repeat: false
        onTriggered: {
            previewWeb.runJavaScript(
                "(function(){ return typeof window.updateMarkdown === 'function'; })();",
                function(ok) {
                    if (!ok) {
                        if (root.loadRetryCount < root.maxLoadRetryCount) {
                            root.loadRetryCount += 1
                            root.restartPreviewEngine()
                            return
                        }
                        root.failLoad("Markdown 预览脚本未就绪（" + root.previewHtmlPath + "）")
                        return
                    }
                    root.bridgeActive = true
                    root.pushMarkdown()
                })
        }
    }

    Timer {
        id: startupGuard
        interval: 60000
        repeat: false
        onTriggered: {
            if (!root.pageReady) {
                if (root.loadRetryCount < root.maxLoadRetryCount) {
                    root.loadRetryCount += 1
                    root.restartPreviewEngine()
                } else {
                    root.failLoad("Markdown 预览页面加载超时（" + root.previewHtmlPath + "）")
                }
            }
        }
    }

    Component.onCompleted: {
        estimatedHeight = estimateHeight()
        hasStarted = true
        root.restartPreviewEngine()
    }
}
