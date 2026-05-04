import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "transparent"

    // External bindings
    property var aiSession: null
    property var aiUi: null
    readonly property var ctx: typeof appContext !== "undefined" ? appContext : null
    readonly property string iconBase: "qrc:/qt/qml/visualization for hexo/assets/iconpark/"
    readonly property string appIcon: "qrc:/qt/qml/visualization for hexo/assets/app-icon.png"
    readonly property string siteTitle: ctx && ctx.configMap ? (ctx.configMap["title"] || "") : ""
    readonly property string userAvatarChar: siteTitle.length > 0 ? siteTitle.charAt(0) : "我"
    property color md3Primary: "#1B6EF3"
    property color md3OnPrimary: "#FFFFFF"
    property color md3PrimaryContainer: "#D8E2FF"
    property color md3OnPrimaryContainer: "#001A41"
    property color md3Surface: "#F9F9FF"
    property color md3OnSurface: "#1A1B20"
    property color md3SurfaceContainer: "#EDEEF4"
    property color md3SurfaceContainerHigh: "#E7E8EE"
    property color md3OnSurfaceVariant: "#44474E"
    property color md3OutlineVariant: "#C4C6D0"
    property color md3Error: "#BA1A1A"
    property color md3ErrorContainer: "#FFDAD6"
    property int shapeMedium: 12

    signal closeRequested()
    signal applyAllRequested()
    signal rejectAllRequested()
    signal applyChangesRequested()

    // ========== Shared tooltip style (matches project IconActionButton) ==========
    component TipButton: Rectangle {
        id: tipBtn
        property string iconSource: ""
        property string tipText: ""
        property bool danger: false
        property int iconSize: 18
        property real iconRotation: 0
        property color iconColor: danger && tipBtnMouse.containsMouse ? root.md3Error : root.md3OnSurfaceVariant

        width: 28; height: 28; radius: 14
        color: danger && tipBtnMouse.containsMouse
            ? Qt.rgba(0.73,0.10,0.10,0.1)
            : (tipBtnMouse.containsMouse ? Qt.rgba(0,0,0,0.06) : "transparent")

        IconImage {
            anchors.centerIn: parent
            source: tipBtn.iconSource
            width: tipBtn.iconSize
            height: tipBtn.iconSize
            color: tipBtn.iconColor
            rotation: tipBtn.iconRotation
        }

        MouseArea {
            id: tipBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: tipBtn.clicked()
        }

        signal clicked()

        ToolTip {
            visible: tipBtnMouse.containsMouse && tipBtn.tipText.length > 0
            text: tipBtn.tipText
            delay: 120
            timeout: 2200
            contentItem: Text {
                text: tipBtn.tipText
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
    }

    // ========== State ==========
    property string currentConvId: ""
    property var conversationList: []
    property bool showHistory: false
    ListModel { id: chatModel }

    // ========== Conversation management ==========
    function refreshConversationList() {
        if (!ctx || !ctx.aiChat) return
        conversationList = ctx.aiChat.conversationList()
    }

    function createNewConversation() {
        if (!ctx || !ctx.aiChat) return
        var postPath = ctx.openedPostPath || ""
        var postTitle = ctx.openedPostTitle || ""
        var convId = ctx.aiChat.createConversation(postPath, postTitle)
        refreshConversationList()
        currentConvId = convId
        chatModel.clear()
        showHistory = false
    }

    function switchToConversation(convId) {
        currentConvId = convId
        loadChatHistory()
        showHistory = false
    }

    function deleteConversation(convId) {
        if (!ctx || !ctx.aiChat) return
        ctx.aiChat.deleteConversation(convId)
        refreshConversationList()
        if (currentConvId === convId) {
            currentConvId = ""
            chatModel.clear()
        }
    }

    // ========== Chat functions ==========
    function appendMessage(msg) {
        chatModel.append({
            role: msg.role || "user",
            content: msg.content || "",
            ts: Number(msg.ts || Date.now())
        })
        if (ctx && ctx.aiChat && currentConvId) {
            ctx.aiChat.appendMessage(currentConvId, msg.role || "user", msg.content || "", Number(msg.ts || Date.now()))
        }
        scrollToBottom()
    }

    function loadChatHistory() {
        if (!ctx || !ctx.aiChat || !currentConvId) {
            chatModel.clear()
            return
        }
        var loaded = ctx.aiChat.loadConversation(currentConvId) || []
        chatModel.clear()
        for (var i = 0; i < loaded.length; i++) {
            var m = loaded[i]
            chatModel.append({
                role: m.role || "user",
                content: m.content || "",
                ts: Number(m.ts || 0)
            })
        }
        scrollToBottom()
    }

    function sendChat() {
        if (!ctx) return
        var text = inputArea.text.trim()
        if (text.length === 0) return

        if (!currentConvId) {
            createNewConversation()
            if (!currentConvId) return
        }

        inputArea.text = ""

        if (aiSession.streaming) {
            ctx.aiChat.cancel()
        }
        aiSession.streaming = true
        aiSession.streamingText = ""

        var refs = []
        if (aiUi && aiUi.referencedPosts) {
            for (var i = 0; i < aiUi.referencedPosts.length; i++) {
                refs.push(ctx.getReferenceContext(aiUi.referencedPosts[i].path))
            }
        }

        appendMessage({ role: "user", content: text, ts: Date.now() })

        var reqId = ctx.aiChat.sendMessage(
            currentConvId,
            text,
            ctx.openedPostBody,
            refs
        )
        aiSession.currentRequestId = reqId
    }

    function scrollToBottom() {
        Qt.callLater(function() {
            if (messagesView.count > 0) messagesView.positionViewAtEnd()
        })
    }

    // ========== AI signals ==========
    Connections {
        target: ctx ? ctx.aiChat : null
        enabled: !!ctx

        function onChatStarted(reqId) {
            if (reqId !== aiSession.currentRequestId) return
        }

        function onChatChunk(reqId, delta) {
            if (reqId !== aiSession.currentRequestId) return
            aiSession.streamingText += delta
            scrollToBottom()
        }

        function onChatDone(reqId, fullText, proposedBody) {
            if (reqId !== aiSession.currentRequestId) return
            aiSession.streaming = false
            aiSession.streamingText = ""

            appendMessage({ role: "assistant", content: fullText, ts: Date.now() })

            if (proposedBody.length > 0 && proposedBody !== ctx.openedPostBody) {
                var hunks = ctx.computeDiff(ctx.openedPostBody, proposedBody)
                aiSession.pendingDiff = { hunks: hunks, proposed: proposedBody, original: ctx.openedPostBody }
                aiSession.hunkDecisions = ({})
            }
            refreshConversationList()
        }

        function onChatError(reqId, message) {
            if (reqId !== aiSession.currentRequestId) return
            aiSession.streaming = false
            aiSession.streamingText = ""
            appendMessage({ role: "error", content: message || "请求失败", ts: Date.now() })
            refreshConversationList()
        }
    }

    // ========== Layout ==========
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Header ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 8

                TipButton {
                    iconSource: root.iconBase + "up.svg"
                    iconSize: 16
                    iconRotation: -90
                    tipText: "返回"
                    visible: root.showHistory
                    onClicked: root.showHistory = false
                }

                Text {
                    text: root.showHistory ? "对话历史" : "AI 编辑"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: root.md3OnSurface
                    Layout.fillWidth: true
                }

                TipButton {
                    iconSource: root.showHistory ? (root.iconBase + "plus.svg") : (root.iconBase + "menu.svg")
                    tipText: root.showHistory ? "新建对话" : "对话历史"
                    onClicked: {
                        if (root.showHistory) {
                            root.createNewConversation()
                        } else {
                            root.refreshConversationList()
                            root.showHistory = true
                        }
                    }
                }

                TipButton {
                    iconSource: root.iconBase + "close.svg"
                    tipText: "关闭"
                    onClicked: root.closeRequested()
                }
            }

            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.md3OutlineVariant }
        }

        // ---- Content: StackLayout switching between Chat and History ----
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.showHistory ? 1 : 0

            // ---- Index 0: Chat view ----
            ColumnLayout {
                spacing: 0

                // Messages area
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 4

                    Column {
                        anchors.centerIn: parent; spacing: 8
                        visible: chatModel.count === 0 && !(aiSession && aiSession.streaming)
                        IconImage { anchors.horizontalCenter: parent.horizontalCenter; source: root.iconBase + "ai-magic.svg"; width: 32; height: 32; color: root.md3OnSurfaceVariant; opacity: 0.5 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "开始与 AI 对话"; font.pixelSize: 14; font.weight: Font.Medium; color: root.md3OnSurface }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "描述你想做的修改，例如「优化开头」"; font.pixelSize: 12; color: root.md3OnSurfaceVariant }
                    }

                    ListView {
                        id: messagesView
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        model: chatModel
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: 1200

                        footer: Item {
                            width: messagesView.width
                            height: (aiSession && aiSession.streaming) ? streamBubbleCol.implicitHeight + 16 : 0
                            visible: height > 0

                            Column {
                                id: streamBubbleCol
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.right: parent.right; anchors.rightMargin: 50
                                anchors.top: parent.top; anchors.topMargin: 4

                                readonly property bool hasText: aiSession && aiSession.streamingText.length > 0

                                Rectangle {
                                    width: streamBubbleCol.hasText
                                        ? Math.min(Math.max(160, streamText.implicitWidth + 20), streamBubbleCol.width)
                                        : Math.min(thinkingRow.implicitWidth + 24, streamBubbleCol.width)
                                    height: streamBubbleCol.hasText ? streamText.implicitHeight + 16 : 36
                                    radius: root.shapeMedium
                                    color: root.md3SurfaceContainer

                                    Row {
                                        id: thinkingRow; anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12; spacing: 6
                                        visible: !streamBubbleCol.hasText
                                        IconImage { anchors.verticalCenter: parent.verticalCenter; source: root.iconBase + "ai-magic.svg"; width: 14; height: 14; color: root.md3OnSurfaceVariant; opacity: 0.35 }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: "AI 思考中"; font.pixelSize: 13; color: root.md3OnSurfaceVariant; opacity: 0.5 }
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                            Repeater {
                                                model: 3
                                                delegate: Rectangle {
                                                    width: 5; height: 5; radius: 2.5; color: root.md3OnSurfaceVariant; opacity: 0.4
                                                    SequentialAnimation on opacity {
                                                        loops: Animation.Infinite; running: thinkingRow.visible
                                                        PauseAnimation { duration: index * 160 }
                                                        NumberAnimation { from: 0.4; to: 1.0; duration: 320 }
                                                        NumberAnimation { from: 1.0; to: 0.4; duration: 320 }
                                                        PauseAnimation { duration: (2 - index) * 160 }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    TextEdit {
                                        id: streamText; x: 8; y: 8; width: parent.width - 16
                                        visible: streamBubbleCol.hasText
                                        text: aiSession ? aiSession.streamingText : ""
                                        font.pixelSize: 13; color: root.md3OnSurface; wrapMode: TextEdit.Wrap; readOnly: true; selectByMouse: true
                                    }
                                }
                            }
                        }

                        Connections {
                            target: aiSession
                            function onStreamingTextChanged() {
                                if (aiSession && aiSession.streaming) Qt.callLater(function() { messagesView.positionViewAtEnd() })
                            }
                            function onStreamingChanged() {
                                if (aiSession && aiSession.streaming) Qt.callLater(function() { messagesView.positionViewAtEnd() })
                            }
                        }

                        delegate: Item {
                            width: messagesView.width
                            height: msgRow.height + 12

                            property bool isUser: model.role === "user"
                            property bool isError: model.role === "error"

                            Row {
                                id: msgRow
                                anchors.top: parent.top; anchors.topMargin: 6
                                spacing: 8
                                anchors.left: isUser ? undefined : parent.left
                                anchors.right: isUser ? parent.right : undefined
                                anchors.leftMargin: isUser ? 0 : 4
                                anchors.rightMargin: isUser ? 4 : 0
                                layoutDirection: isUser ? Qt.RightToLeft : Qt.LeftToRight

                                // User avatar
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: root.md3Primary
                                    visible: isUser

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.userAvatarChar
                                        font.pixelSize: 12; font.weight: Font.Bold
                                        color: root.md3OnPrimary
                                    }
                                }

                                // AI avatar — same style, SVG icon centered in circle
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: root.md3PrimaryContainer
                                    visible: !isUser
                                    layer.enabled: true

                                    Image {
                                        anchors.fill: parent
                                        source: root.appIcon
                                        sourceSize: Qt.size(56, 56)
                                        smooth: true
                                    }
                                }

                                Rectangle {
                                    width: Math.min(bubbleText.implicitWidth + 16, msgRow.parent.width - 80)
                                    height: bubbleText.implicitHeight + 12
                                    radius: 12
                                    color: isError ? root.md3ErrorContainer
                                        : isUser ? root.md3PrimaryContainer
                                        : root.md3SurfaceContainerHigh

                                    TextEdit {
                                        id: bubbleText
                                        anchors.fill: parent; anchors.margins: 6
                                        text: model.content || ""
                                        font.pixelSize: 13
                                        color: isError ? root.md3Error : root.md3OnSurface
                                        wrapMode: TextEdit.Wrap; readOnly: true; selectByMouse: true
                                    }
                                }
                            }
                        }
                    }
                }

                // Diff proposal card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? diffStatusContent.implicitHeight + 20 : 0
                    visible: aiSession && aiSession.pendingDiff !== null
                    color: root.md3PrimaryContainer
                    radius: root.shapeMedium
                    Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.topMargin: 4

                    Column {
                        id: diffStatusContent
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            width: parent.width
                            text: {
                                var count = aiSession && aiSession.pendingDiff ? aiSession.pendingDiff.hunks.filter(function(h) { return h.type !== "equal" }).length : 0
                                return "AI 提议 " + count + " 处修改"
                            }
                            font.pixelSize: 13; font.weight: Font.DemiBold; color: root.md3OnPrimaryContainer; wrapMode: Text.Wrap
                        }

                        Row {
                            spacing: 8
                            Rectangle {
                                width: acceptAllText.implicitWidth + 20; height: 30; radius: 15; color: root.md3Primary
                                Text { id: acceptAllText; anchors.centerIn: parent; text: "全部接受"; font.pixelSize: 12; font.weight: Font.Medium; color: root.md3OnPrimary }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.applyAllRequested() }
                            }
                            Rectangle {
                                width: rejectAllText.implicitWidth + 20; height: 30; radius: 15
                                color: "transparent"; border.width: 1; border.color: root.md3OutlineVariant
                                Text { id: rejectAllText; anchors.centerIn: parent; text: "全部拒绝"; font.pixelSize: 12; font.weight: Font.Medium; color: root.md3OnSurfaceVariant }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.rejectAllRequested() }
                            }
                        }
                    }
                }

                // Input area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(inputCol.implicitHeight + 16, 200)
                    color: root.md3Surface
                    border.width: 1; border.color: root.md3OutlineVariant; radius: root.shapeMedium
                    Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.bottomMargin: 8; Layout.topMargin: 4

                    Column {
                        id: inputCol
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 4

                        ScrollView {
                            width: parent.width
                            height: Math.min(Math.max(inputArea.implicitHeight, 36), 120)
                            clip: true

                            TextArea {
                                id: inputArea
                                placeholderText: "输入指令... (Enter 发送, Shift+Enter 换行)"
                                font.pixelSize: 13; color: root.md3OnSurface; wrapMode: TextArea.Wrap; selectByMouse: true; background: null

                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (event.modifiers & Qt.ShiftModifier) return
                                        root.sendChat()
                                        event.accepted = true
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right; spacing: 6
                            Text { text: "Enter 发送"; font.pixelSize: 11; color: root.md3OnSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: sendText.implicitWidth + 20; height: 28; radius: 14
                                color: (aiSession && aiSession.streaming) ? root.md3ErrorContainer : root.md3Primary
                                opacity: (aiSession && aiSession.streaming) || inputArea.text.trim().length > 0 ? 1 : 0.5
                                Text {
                                    id: sendText; anchors.centerIn: parent
                                    text: (aiSession && aiSession.streaming) ? "停止" : "发送"
                                    font.pixelSize: 12; font.weight: Font.Medium
                                    color: (aiSession && aiSession.streaming) ? root.md3Error : root.md3OnPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (aiSession && aiSession.streaming) {
                                            appContext.aiChat.cancel()
                                            aiSession.streaming = false
                                            aiSession.streamingText = ""
                                        } else {
                                            root.sendChat()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- Index 1: History view ----
            ColumnLayout {
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Empty state
                    Column {
                        anchors.centerIn: parent; spacing: 8
                        visible: root.conversationList.length === 0
                        IconImage { anchors.horizontalCenter: parent.horizontalCenter; source: root.iconBase + "menu.svg"; width: 32; height: 32; color: root.md3OnSurfaceVariant; opacity: 0.4 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "暂无对话历史"; font.pixelSize: 14; font.weight: Font.Medium; color: root.md3OnSurface }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "开始与 AI 对话后将自动保存"; font.pixelSize: 12; color: root.md3OnSurfaceVariant }
                    }

                    ListView {
                        id: histListView
                        anchors.fill: parent
                        anchors.topMargin: 4
                        clip: true
                        spacing: 2
                        model: root.conversationList

                        delegate: Rectangle {
                            id: histDelegate
                            width: histListView.width
                            height: 56
                            radius: root.shapeMedium
                            color: histMouse.containsMouse ? Qt.rgba(0,0,0,0.04) : "transparent"
                            property bool renaming: false

                            // MouseArea below RowLayout so buttons can receive clicks
                            MouseArea {
                                id: histMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!histDelegate.renaming) root.switchToConversation(modelData.id)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 8
                                spacing: 8

                                // AI icon
                                IconImage {
                                    source: root.iconBase + "ai-magic.svg"
                                    width: 18; height: 18
                                    color: root.md3OnSurfaceVariant
                                    opacity: 0.5
                                }

                                // Title / Rename input
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        visible: !histDelegate.renaming
                                        text: modelData.title || "新对话"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: root.md3OnSurface
                                        elide: Text.ElideRight
                                    }

                                    TextInput {
                                        id: renameInput
                                        width: parent.width
                                        visible: histDelegate.renaming
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: root.md3OnSurface
                                        clip: true
                                        selectByMouse: true
                                        text: modelData.title || ""
                                        property string originalText: modelData.title || ""

                                        onAccepted: {
                                            var t = renameInput.text.trim()
                                            if (t.length > 0 && t !== renameInput.originalText && ctx && ctx.aiChat) {
                                                ctx.aiChat.renameConversation(modelData.id, t)
                                                root.refreshConversationList()
                                            }
                                            histDelegate.renaming = false
                                        }

                                        Keys.onEscapePressed: {
                                            renameInput.text = renameInput.originalText
                                            histDelegate.renaming = false
                                        }

                                        onActiveFocusChanged: {
                                            if (!activeFocus && histDelegate.renaming) {
                                                renameInput.accepted()
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.leftMargin: -4
                                            anchors.rightMargin: -4
                                            anchors.topMargin: -2
                                            anchors.bottomMargin: -2
                                            radius: 4
                                            color: "transparent"
                                            border.width: histDelegate.renaming ? 1 : 0
                                            border.color: root.md3Primary
                                            z: -1
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: {
                                            var d = new Date(modelData.updatedAt || 0)
                                            var now = new Date()
                                            var isToday = d.toDateString() === now.toDateString()
                                            if (isToday) {
                                                return d.getHours().toString().padStart(2, "0") + ":" + d.getMinutes().toString().padStart(2, "0")
                                            }
                                            return (d.getMonth()+1) + "/" + d.getDate() + " " + d.getHours().toString().padStart(2, "0") + ":" + d.getMinutes().toString().padStart(2, "0")
                                        }
                                        font.pixelSize: 11
                                        color: root.md3OnSurfaceVariant
                                    }
                                }

                                // Rename button
                                TipButton {
                                    iconSource: root.iconBase + "edit.svg"
                                    tipText: "重命名"
                                    z: 1
                                    onClicked: {
                                        histDelegate.renaming = true
                                        renameInput.forceActiveFocus()
                                        renameInput.selectAll()
                                    }
                                }

                                // Delete button
                                TipButton {
                                    iconSource: root.iconBase + "delete.svg"
                                    tipText: "删除对话"
                                    danger: true
                                    z: 1
                                    onClicked: root.deleteConversation(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== Initialization ==========
    Component.onCompleted: {
        Qt.callLater(function() {
            refreshConversationList()
        })
    }
}
