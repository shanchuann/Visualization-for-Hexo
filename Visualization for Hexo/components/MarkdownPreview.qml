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
    property bool switching: false
    property string pendingFullSource: ""
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
        root.pendingFullSource = ""
    }

    function beginContentSwitch() {
        const source = root.markdownText || ""
        if (source.length === 0) {
            root.switching = false
            renderCompleteChecker.stopChecking()
            return
        }
        root.switching = true
        renderCompleteChecker.stopChecking()
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
            root.switching = false
            return
        }

        // Staged loading: push first part for long articles, then full content after render
        var pushSource = source
        if (source.length > 3000 && root.pendingFullSource.length === 0) {
            var cutAt = source.lastIndexOf('\n\n', 2500)
            if (cutAt < 1500) cutAt = source.lastIndexOf('\n', 2500)
            if (cutAt < 1500) cutAt = 2500
            root.pendingFullSource = source
            pushSource = source.substring(0, cutAt) + "\n\n*(剩余内容加载中...)*"
        } else {
            root.pendingFullSource = ""
        }

        root.lastPushedMarkdown = pushSource
        root.lastPushedFontPx = fontPx
        root.lastPushedLineSpacing = lineHeight

        doPushContent(pushSource, fontPx, lineHeight, root.pendingFullSource.length > 0)
    }

    function doPushContent(source, fontPx, lineHeight, isPartial) {
        const payload = JSON.stringify(source)
        const js = "(function(){ var p = " + payload + "; try{ console.log('[HexoBridge] PUSH payload_len=' + (p && p.length ? p.length : 0)); }catch(e){} var cssId='__hexo_hide_scrollbar__'; if(!document.getElementById(cssId)){ try{ var s=document.createElement('style'); s.id=cssId; s.textContent='html,body{height:auto;margin:0;padding:0;overflow:hidden;min-height:auto;} body{scrollbar-width:none;-ms-overflow-style:none;} body::-webkit-scrollbar{width:0;height:0;background:transparent;}'; document.head.appendChild(s);}catch(_){/* ignore */} } if(typeof window.updateMarkdown === 'function'){ window.updateMarkdown(p, { bodyFontSize: " + fontPx + ", lineSpacing: " + lineHeight + " }); return true; } return false; })();"
        previewWeb.runJavaScript(js, function(ok) {
            root.bridgeActive = !!ok
            if (ok) {
                heightProbeTimer.restart()
                delayedHeightProbeTimer.restart()
                // Immediately probe height so checker can finish faster on cache hits
                previewWeb.runJavaScript(
                    "(function(){ return Math.max(document.documentElement.scrollHeight || 0, document.body.scrollHeight || 0); })();",
                    function(initialH) {
                        if (initialH && initialH > 0) {
                            root.estimatedHeight = Math.max(520, initialH + 24)
                        }
                        renderCompleteChecker.startChecking(isPartial, initialH)
                    }
                )
            } else {
                switchGuard.restart()
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

        }

        Connections {
            target: previewWeb
            ignoreUnknownSignals: true
            function onRenderProcessTerminated(terminationStatus, exitCode) {
                root.failLoad("渲染进程异常退出（status=" + terminationStatus + ", exitCode=" + exitCode + "）")
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.loadFailed
            color: "#FFFFFF"

            Column {
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 48, 520)
                spacing: 10

                Text {
                    width: parent.width
                    text: "升级版 Markdown 预览暂时不可用"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#1f2328"
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: root.loadError
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    color: "#57606a"
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
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

        Rectangle {
            id: blurOverlay
            anchors.fill: parent
            color: "#E6FFFFFF"
            opacity: root.switching ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Column {
                anchors.top: parent.top
                anchors.topMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Rectangle {
                    id: spinner
                    width: 36
                    height: 36
                    radius: 18
                    color: "transparent"
                    border.width: 3
                    border.color: "#1B6EF3"
                    anchors.horizontalCenter: parent.horizontalCenter
                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: blurOverlay.visible
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "预览加载中..."
                    color: "#57606a"
                    font.pixelSize: 14
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.switching
            }
        }
    }

    Timer {
        id: renderDebounce
        interval: 10
        repeat: false
        onTriggered: root.pushMarkdown()
    }

    Timer {
        id: renderCompleteChecker
        property int lastHeight: -1
        property int stableCount: 0
        property bool checkerRunning: false
        property bool waitingForPartial: false
        interval: 50
        repeat: true
        onTriggered: {
            if (!checkerRunning) return
            previewWeb.runJavaScript(
                "(function(){ return Math.max(document.documentElement.scrollHeight || 0, document.body.scrollHeight || 0); })();",
                function(h) {
                    if (!checkerRunning) return
                    if (h && h > 0) {
                        if (Math.abs(h - lastHeight) <= 2) {
                            stableCount++
                            if (stableCount >= 2) {
                                root.estimatedHeight = Math.max(520, h + 24)
                                if (waitingForPartial && root.pendingFullSource.length > 0) {
                                    // Partial render complete; now push full content
                                    waitingForPartial = false
                                    lastHeight = -1
                                    stableCount = 0
                                    var full = root.pendingFullSource
                                    root.pendingFullSource = ""
                                    root.lastPushedMarkdown = full
                                    var fontPx = root.lastPushedFontPx
                                    var lineHeight = root.lastPushedLineSpacing
                                    var payload = JSON.stringify(full)
                                    var js = "(function(){ var p = " + payload + "; if(typeof window.updateMarkdown === 'function'){ window.updateMarkdown(p, { bodyFontSize: " + fontPx + ", lineSpacing: " + lineHeight + " }); return true; } return false; })();"
                                    previewWeb.runJavaScript(js, function(ok) {
                                        root.bridgeActive = !!ok
                                        if (ok) {
                                            heightProbeTimer.restart()
                                            delayedHeightProbeTimer.restart()
                                            renderCompleteChecker.startChecking(false)
                                        }
                                    })
                                } else {
                                    // Fully rendered; clear blur
                                    root.switching = false
                                    checkerRunning = false
                                    renderCompleteChecker.stop()
                                }
                            }
                        } else {
                            stableCount = 0
                            lastHeight = h
                        }
                    }
                }
            )
        }
        function startChecking(partial, initialHeight) {
            lastHeight = (initialHeight !== undefined && initialHeight > 0) ? initialHeight : -1
            stableCount = 0
            waitingForPartial = partial
            checkerRunning = true
            renderCompleteChecker.restart()
        }
        function stopChecking() {
            checkerRunning = false
            renderCompleteChecker.stop()
        }
    }

    Timer {
        id: retryTimer
        interval: 320
        repeat: false
        onTriggered: root.restartPreviewEngine()
    }

    Timer {
        id: heightProbeTimer
        interval: 30
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
        interval: 250
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
