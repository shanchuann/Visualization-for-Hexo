import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "components"

ApplicationWindow {
    Shortcut {
        sequences: ["Ctrl+S"]
        onActivated: {
            if (appContext.openedPostPath && appContext.openedPostPath.length > 0) {
                appContext.saveOpenedPost(
                    titleInput.text,
                    categoryInput.editText,
                    tagsInput.editText,
                    dateInput.editText,
                    coverInput.text,
                    descriptionInput.text,
                    bodyEdit.text
                );
            }
        }
    }

    id: root
    visible: false
    width: 1100
    height: 700
    x: 0
    y: 0
    minimumWidth: 1100
    minimumHeight: 700
    title: "Visualization for Hexo"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: layoutBg
    onClosing: {
        if (autoSaveTimer.running) {
            root.doAutoSave()
        }
    }

    function toFileUrl(pathText) {
        var text = (pathText || "").trim()
        if (text.length === 0) {
            return ""
        }
        var normalized = text.replace(/\\/g, "/")
        if (!normalized.startsWith("file:/")) {
            normalized = "file:///" + normalized
        }
        return normalized
    }

    function toLocalPath(urlValue) {
        if (!urlValue) {
            return ""
        }
        if (urlValue.toLocalFile) {
            var local = urlValue.toLocalFile()
            if (local && local.length > 0) {
                return local
            }
        }
        var text = urlValue.toString ? urlValue.toString() : String(urlValue)
        if (text.startsWith("file:///")) {
            text = text.substring(8)
        } else if (text.startsWith("file://")) {
            text = text.substring(7)
        }
        return text
    }

    function openProjectFolderDialog() {
        var presetUrl = toFileUrl(appContext.currentProjectPath || "")
        if (presetUrl.length > 0) {
            projectFolderDialog.currentFolder = presetUrl
            projectFolderDialog.selectedFolder = presetUrl
        }
        projectFolderDialog.open()
    }

    function showConfirmDialog(title, message, confirmText, isDanger, callback) {
        root.confirmDialogTitle = title
        root.confirmDialogMessage = message
        root.confirmDialogConfirmText = confirmText
        root.confirmDialogIsDanger = isDanger
        root.pendingConfirmCallback = callback
        confirmDialog.open()
    }

    Rectangle {
        id: sceneRoot
        anchors.fill: parent
        color: root.layoutBg
        layer.enabled: root.resizeDegrade
        layer.smooth: true
        layer.mipmap: true
        z: -100
    }

    // ======================== Material Design 3 · Blue Theme ========================
    readonly property color md3Primary: "#1B6EF3"
    readonly property color md3OnPrimary: "#FFFFFF"
    readonly property color md3PrimaryContainer: "#D8E2FF"
    readonly property color md3OnPrimaryContainer: "#001A41"
    readonly property color md3Secondary: "#575E71"
    readonly property color md3OnSecondary: "#FFFFFF"
    readonly property color md3SecondaryContainer: "#DBE2F9"
    readonly property color md3OnSecondaryContainer: "#141B2C"
    readonly property color md3Tertiary: "#715573"
    readonly property color md3Error: "#BA1A1A"
    readonly property color md3OnError: "#FFFFFF"
    readonly property color md3ErrorContainer: "#FFDAD6"
    readonly property color md3Surface: "#F9F9FF"
    readonly property color md3OnSurface: "#1A1B20"
    readonly property color md3SurfaceVariant: "#E0E2EC"
    readonly property color md3OnSurfaceVariant: "#44474E"
    readonly property color md3Outline: "#74777F"
    readonly property color md3OutlineVariant: "#C4C6D0"
    readonly property color md3FocusSoft: "#8EA4CF"
    readonly property color md3SurfaceDim: "#D9D9E0"
    readonly property color md3SurfaceContainer: "#EDEEF4"
    readonly property color md3SurfaceContainerLow: "#F3F3FA"
    readonly property color md3SurfaceContainerHigh: "#E7E8EE"
    readonly property color md3SurfaceContainerHighest: "#E2E2E9"
    readonly property color md3SurfaceContainerLowest: "#FFFFFF"
    readonly property color md3InverseSurface: "#2F3036"
    readonly property color md3InverseOnSurface: "#F0F0F7"
    readonly property color md3InversePrimary: "#ADC6FF"
    readonly property color layoutBg: "#FFFFFF"
    readonly property color sidePanelBg: "#F8F9FC"
    readonly property color sidePanelItem: "#EEF2FA"
    readonly property color readingPaper: "#FFFFFF"
    readonly property color readingInk: "#2B261B"

    // MD3 Shape tokens
    readonly property int shapeSmall: 8
    readonly property int shapeMedium: 12
    readonly property int shapeLarge: 16
    readonly property int shapeExtraLarge: 28

    // Unified control tokens
    readonly property int controlHeight: 38
    readonly property int controlRadius: 18
    readonly property int menuItemHeight: 34
    readonly property int inputHeight: 38
    property int uiTitleFontSize: 50
    property int uiBodyFontSize: 18
    property real uiLineSpacing: 1.95
    property int previewDebounceMs: 320
    property bool consoleVisible: false
    property bool consoleExpanded: true
    property bool aiKeyEditing: false
    property bool sidebarSearchMode: false
    property string sidebarSearchQuery: ""
    property var consoleCommandHistory: []
    property int consoleHistoryIndex: -1
    property var backupHistory: []
    property bool pluginDialogPending: false
    property int pluginLogStart: 0
    property string pluginDialogName: ""
    property string pluginDialogDesc: ""
    property int pluginDialogExitCode: -1
    property int settingsTabIndex: 0
    property int articleViewMode: 1 // 0: source, 1: preview
    property bool resizeDegrade: false
    property bool suppressResizeDegrade: false
    readonly property bool degradeRendering: false
    readonly property int topBarButtonSize: 26
    readonly property int fixedSidebarWidth: 370
    readonly property int consoleCollapsedHeight: 90
    property string diagnosticsText: ""
    property var topicStats: ({
        categoryCount: 0,
        tagCount: 0,
        updateFrequency: "样本不足",
        categoryTop: [],
        tagTop: [],
        trend: [],
        trendMax: 1
    })
    property string previewMarkdownSource: ""
    property string previewCoverSource: ""
    property string lastPreviewMarkdown: ""
    property bool autoSaveEnabled: true
    property string autoSaveStatus: ""
    property var envStatus: ({ node: false, hexo: false, git: false, project: false })
    property bool envStatusVisible: false
    property string pendingInitProjectPath: ""
    property bool initProjectBusy: false
    property string initProjectStatus: ""
    property string pendingDeleteProjectPath: ""
    property string pendingDeleteProjectName: ""
    property var pendingConfirmCallback: null
    property string confirmDialogTitle: ""
    property string confirmDialogMessage: ""
    property string confirmDialogConfirmText: "确认"
    property bool confirmDialogIsDanger: false
    property real normalWindowX: 0
    property real normalWindowY: 0
    property real normalWindowWidth: width
    property real normalWindowHeight: height
    property bool maximizeToggleActive: false
    readonly property int edgeSnapThreshold: 18
    readonly property string iconBase: "qrc:/qt/qml/visualization for hexo/assets/iconpark/"
    readonly property bool isWindowMaximized: root.visibility === Window.Maximized || ((root.windowState & Qt.WindowMaximized) !== 0)
    readonly property bool isWindowFullScreen: root.visibility === Window.FullScreen || ((root.windowState & Qt.WindowFullScreen) !== 0)

    // AI edit mode state
    QtObject {
        id: aiUi
        property bool editMode: false
        property var referencedPosts: []
    }

    QtObject {
        id: aiSession
        property bool streaming: false
        property string streamingText: ""
        property int currentRequestId: 0
        property var pendingDiff: null
        property var hunkDecisions: ({})
    }

    readonly property int diffChangeCount: {
        if (!aiSession.pendingDiff) return 0
        var count = 0
        for (var i = 0; i < aiSession.pendingDiff.hunks.length; i++) {
            if (aiSession.pendingDiff.hunks[i].type !== "equal") count++
        }
        return count
    }
    readonly property int diffDecidedCount: {
        if (!aiSession.pendingDiff) return 0
        var count = 0
        for (var i = 0; i < aiSession.pendingDiff.hunks.length; i++) {
            var h = aiSession.pendingDiff.hunks[i]
            if (h.type !== "equal" && aiSession.hunkDecisions[h.hunkId] !== undefined) count++
        }
        return count
    }
    readonly property bool hasAnyDiffDecision: diffDecidedCount > 0

    function enterAiEditMode() {
        if (!appContext.openedPostPath) return
        aiUi.editMode = true
    }

    function exitAiEditMode() {
        if (aiSession.pendingDiff) {
            root.showConfirmDialog(
                "退出 AI 编辑",
                "当前有未处理的 AI 修改建议，确定要退出吗？",
                "退出",
                false,
                function() {
                    aiSession.pendingDiff = null
                    aiSession.hunkDecisions = ({})
                    aiUi.editMode = false
                    if (appContext.aiChat) appContext.aiChat.cancel()
                }
            )
            return
        }
        aiUi.editMode = false
        aiUi.referencedPosts = []
        if (appContext.aiChat) appContext.aiChat.cancel()
    }

    function rebuildDiffBody(original, hunks, decisions) {
        var result = []
        for (var i = 0; i < hunks.length; i++) {
            var h = hunks[i]
            if (h.type === "equal") {
                result = result.concat(h.origLines)
            } else if (decisions === null) {
                // null means accept all
                result = result.concat(h.propLines)
            } else {
                if (decisions[h.hunkId] === true) {
                    result = result.concat(h.propLines)
                } else {
                    result = result.concat(h.origLines)
                }
            }
        }
        var body = result.join("\n")
        if (original.charAt(original.length - 1) === "\n" && body.charAt(body.length - 1) !== "\n") {
            body += "\n"
        }
        return body
    }

    onConsoleVisibleChanged: {
        if (consoleVisible) {
            consoleExpanded = true
        }
    }

    onSidebarSearchModeChanged: {
        if (!sidebarSearchMode) {
            root.sidebarSearchQuery = ""
        } else {
            Qt.callLater(function() { searchInput.forceActiveFocus() })
        }
    }

    onArticleViewModeChanged: {
        if (!editorContent) {
            return
        }
        editorContent.isMarkdown = articleViewMode === 1
        if (editorContent.isMarkdown) {
            previewRenderTimer.restart()
        }
    }

    function requestResizeDegrade() {
        if (!root.visible || root.suppressResizeDegrade) {
            return
        }
        resizeDegrade = true
        previewRenderTimer.stop()
        resizeSettleTimer.restart()
    }

    onWidthChanged: requestResizeDegrade()
    onHeightChanged: requestResizeDegrade()

    onResizeDegradeChanged: {
        if (!root.contentItem) {
            return
        }
        root.contentItem.layer.enabled = resizeDegrade
        root.contentItem.layer.smooth = true
        root.contentItem.layer.mipmap = true
    }

    onUiBodyFontSizeChanged: {
        if (editorContent && editorContent.isMarkdown) {
            root.syncPreviewText(true)
        }
    }

    onUiLineSpacingChanged: {
        if (editorContent && editorContent.isMarkdown) {
            root.syncPreviewText(true)
        }
    }

    onVisibilityChanged: {
        if (!root.visible) {
            return
        }
        if (root.visibility === Window.Maximized || root.visibility === Window.FullScreen) {
            root.maximizeToggleActive = true
        } else if (root.visibility === Window.Windowed) {
            root.maximizeToggleActive = false
        }
        // When Windows maximizes the window (e.g. Aero Snap, taskbar),
        // remember the normal geometry so the custom restore button works.
        if (root.visibility === Window.Maximized) {
            root.rememberNormalWindowGeometry()
        }
        windowStateRefreshTimer.restart()
    }

    onWindowStateChanged: {
        if (!root.visible) {
            return
        }
        root.maximizeToggleActive =
            root.visibility === Window.Maximized
            || root.visibility === Window.FullScreen
            || ((root.windowState & Qt.WindowMaximized) !== 0)
            || ((root.windowState & Qt.WindowFullScreen) !== 0)
        windowStateRefreshTimer.restart()
    }

    function forceMainLayoutSync() {
        if (mainContentSplit) {
            mainContentSplit.forceLayout()
        }
        if (editorScrollView) {
            editorScrollView.returnToBounds()
        }
        if (editorContent && editorContent.isMarkdown) {
            previewRenderTimer.restart()
        }
    }

    function editorContentWidth() {
        return Math.max(400, Math.min(980, editorScrollView.width - 72))
    }

    function editorBodyHeight() {
        if (aiSession && aiSession.pendingDiff) {
            // DiffReviewView: use a reasonable height based on hunk count
            var hunks = aiSession.pendingDiff.hunks || []
            var lineCount = 0
            for (var i = 0; i < hunks.length; i++) {
                lineCount += (hunks[i].origLines ? hunks[i].origLines.length : 0)
                lineCount += (hunks[i].propLines ? hunks[i].propLines.length : 0)
            }
            return Math.max(400, lineCount * 22 + 120)
        }
        var previewHeight = mdPreview.implicitHeight
        if (coverPreview.visible) {
            previewHeight += coverPreview.height + 10
        }

        var contentHeight = editorContent.isMarkdown ? previewHeight : bodyEdit.contentHeight
        return Math.max(contentHeight, 240)
    }

    function restoreNormalGeometry() {
        root.maximizeToggleActive = false
        root.showNormal()
        root.x = normalWindowX
        root.y = normalWindowY
        root.width = normalWindowWidth
        root.height = normalWindowHeight
    }

    function rememberNormalWindowGeometry() {
        if (root.maximizeToggleActive || root.isWindowFullScreen || root.isWindowMaximized) return;
        normalWindowX = root.x;
        normalWindowY = root.y;
        normalWindowWidth = root.width;
        normalWindowHeight = root.height;
    }

    function showWindowMaximizedSafe() {
        root.rememberNormalWindowGeometry()
        root.maximizeToggleActive = true
        root.showMaximized()
        windowStateRefreshTimer.restart()
    }

    function screenForGlobalPoint(globalX, globalY) {
        var screens = Qt.application.screens;
        for (var i = 0; i < screens.length; i++) {
            var sg = screens[i].geometry;
            if (globalX >= sg.x && globalX < sg.x + sg.width && globalY >= sg.y && globalY < sg.y + sg.height)
                return screens[i];
        }
        return root.screen;
    }

    function clampWindowToScreen(screenObj, w, h, targetX, targetY) {
        var ag = screenObj.availableGeometry;
        var clampedW = Math.min(w, ag.width);
        var clampedH = Math.min(h, ag.height);
        var maxX = ag.x + ag.width - clampedW;
        var maxY = ag.y + ag.height - clampedH;
        return Qt.point(
            Math.max(ag.x, Math.min(targetX, maxX)),
            Math.max(ag.y, Math.min(targetY, maxY))
        );
    }

    function applyHorizontalEdgeSnap(screenObj, targetX, w) {
        var ag = screenObj.availableGeometry;
        var leftEdge = ag.x;
        var rightEdge = ag.x + ag.width - w;

        if (Math.abs(targetX - leftEdge) <= root.edgeSnapThreshold)
            return leftEdge;
        if (Math.abs(targetX - rightEdge) <= root.edgeSnapThreshold)
            return rightEdge;
        return targetX;
    }

    function toggleMaximizeRestore() {
        if (root.maximizeToggleActive || root.isWindowFullScreen || root.isWindowMaximized) {
            root.restoreNormalGeometry()
            windowStateRefreshTimer.restart()
        } else {
            root.showWindowMaximizedSafe()
        }
    }

    function addOrInitializeProject(pathText) {
        var p = (pathText || "").trim();
        if (p.length === 0) {
            return;
        }
        if (appContext.isHexoProject(p)) {
            appContext.addProject(p);
            return;
        }
        pendingInitProjectPath = p;
        initProjectDialog.open();
    }

    function bindOpenedPostFields() {
        if (!titleInput || !bodyEdit) {
            return
        }
        root.lastPreviewMarkdown = ""
        root.autoSaveEnabled = false
        titleInput.text = Qt.binding(function() { return appContext.openedPostTitle })
        categoryInput.editText = Qt.binding(function() { return appContext.openedPostCategory })
        tagsInput.editText = Qt.binding(function() { return appContext.openedPostTags })
        dateInput.editText = Qt.binding(function() { return appContext.openedPostDate })
        coverInput.text = Qt.binding(function() { return appContext.openedPostCover })
        descriptionInput.text = Qt.binding(function() { return appContext.openedPostDescription })
        bodyEdit.text = Qt.binding(function() { return appContext.openedPostBody })
        if (editorContent && editorContent.isMarkdown) {
            previewRenderTimer.restart()
        } else {
            root.previewMarkdownSource = ""
        }
        Qt.callLater(function() { root.autoSaveEnabled = true })
    }

    function triggerAutoSave() {
        if (!root.autoSaveEnabled) return
        if (!appContext.openedPostPath || appContext.openedPostPath.length === 0) return
        autoSaveTimer.restart()
    }

    function doAutoSave() {
        if (aiSession && aiSession.pendingDiff) return
        if (!appContext.openedPostPath || appContext.openedPostPath.length === 0) return
        appContext.saveOpenedPost(
            titleInput.text,
            categoryInput.editText,
            tagsInput.editText,
            dateInput.editText,
            coverInput.text,
            descriptionInput.text,
            bodyEdit.text
        )
        root.autoSaveStatus = "已保存"
        autoSaveStatusFade.restart()
    }

    function requestDeleteProject(name, path) {
        pendingDeleteProjectName = name || ""
        pendingDeleteProjectPath = path || ""
        if (pendingDeleteProjectPath.length === 0) {
            return
        }
        deleteProjectDialog.open()
    }

    function syncPreviewText(forceRender) {
        if (forceRender === undefined)
            forceRender = false;
        if (!bodyEdit) {
            return;
        }
        if (!forceRender && (!editorContent || !editorContent.isMarkdown)) {
            return;
        }
        var coverUrl = appContext.resolveCoverForPreview(coverInput.text, appContext.openedPostPath || "") || "";
        root.previewCoverSource = coverUrl
        var nextText = bodyEdit.text || "";
        nextText = nextText.replace(/^\s*\n+/, "")
        if (nextText.trim().length === 0) {
            root.lastPreviewMarkdown = ""
            root.previewMarkdownSource = ""
            return
        }
        if (!forceRender && root.lastPreviewMarkdown === nextText) {
            return
        }
        root.lastPreviewMarkdown = nextText
        root.previewMarkdownSource = nextText
    }

    function toggleConsoleExpanded() {
        if (!root.consoleVisible) {
            return;
        }
        root.consoleExpanded = !root.consoleExpanded;
    }

    function toggleConsoleVisibility() {
        root.consoleVisible = !root.consoleVisible;
        if (root.consoleVisible) {
            root.consoleExpanded = true;
        }
    }

    component IconActionButton: Button {
        id: iconBtn
        property string iconSource: ""
        property string toolTipText: ""
        property bool danger: false
        property bool iconIsRaster: iconSource.length > 4 && iconSource.slice(-4).toLowerCase() === ".png"
        implicitWidth: root.controlHeight
        implicitHeight: root.controlHeight
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        flat: true
        background: Rectangle {
            radius: root.shapeSmall
            color: iconBtn.danger && iconBtn.hovered
                ? root.md3ErrorContainer
                : (iconBtn.down
                ? Qt.rgba(root.md3OnSurfaceVariant.r, root.md3OnSurfaceVariant.g, root.md3OnSurfaceVariant.b, 0.18)
                : (iconBtn.hovered ? root.hoverOverlay(true) : "transparent"))
        }
        contentItem: Item {
            Loader {
                anchors.centerIn: parent
                sourceComponent: iconBtn.iconIsRaster ? rasterIconComp : vectorIconComp
            }
        }

        Component {
            id: vectorIconComp
            IconImage {
                width: 18
                height: 18
                source: iconBtn.iconSource
                color: iconBtn.danger && iconBtn.hovered ? root.md3Error : root.md3OnSurfaceVariant
            }
        }

        Component {
            id: rasterIconComp
            Image {
                width: 18
                height: 18
                source: iconBtn.iconSource
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(18, 18)
                smooth: true
            }
        }

        ToolTip {
            visible: iconBtn.hovered && iconBtn.toolTipText.length > 0
            text: iconBtn.toolTipText
            delay: 120
            timeout: 2200

            contentItem: Text {
                text: iconBtn.toolTipText
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

    component PageScrollBar: ScrollBar {
        id: wideSb
        policy: ScrollBar.AsNeeded
        minimumSize: 0.08
        interactive: true
        hoverEnabled: true
        width: orientation === Qt.Vertical ? 18 : undefined
        height: orientation === Qt.Horizontal ? 18 : undefined

        contentItem: Rectangle {
            implicitWidth: wideSb.orientation === Qt.Vertical ? 14 : wideSb.availableWidth
            implicitHeight: wideSb.orientation === Qt.Horizontal ? 14 : wideSb.availableHeight
            radius: 7
            color: wideSb.pressed
                ? Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, 0.8)
                : (wideSb.hovered
                    ? Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, 0.65)
                    : Qt.rgba(root.md3Outline.r, root.md3Outline.g, root.md3Outline.b, 0.52))
        }

        background: Rectangle {
            implicitWidth: wideSb.orientation === Qt.Vertical ? 14 : wideSb.availableWidth
            implicitHeight: wideSb.orientation === Qt.Horizontal ? 14 : wideSb.availableHeight
            radius: 7
            color: Qt.rgba(root.md3OnSurfaceVariant.r, root.md3OnSurfaceVariant.g, root.md3OnSurfaceVariant.b, 0.12)
        }
    }

    component ListScrollBar: ScrollBar {
        id: listSb
        policy: ScrollBar.AsNeeded
        minimumSize: 0.1
        interactive: true
        hoverEnabled: true
        width: orientation === Qt.Vertical ? 6 : undefined
        height: orientation === Qt.Horizontal ? 6 : undefined

        contentItem: Rectangle {
            implicitWidth: listSb.orientation === Qt.Vertical ? 3 : listSb.availableWidth
            implicitHeight: listSb.orientation === Qt.Horizontal ? 3 : listSb.availableHeight
            radius: 1.5
            color: listSb.pressed
                ? Qt.rgba(root.md3Outline.r, root.md3Outline.g, root.md3Outline.b, 0.72)
                : (listSb.hovered
                    ? Qt.rgba(root.md3Outline.r, root.md3Outline.g, root.md3Outline.b, 0.58)
                    : Qt.rgba(root.md3Outline.r, root.md3Outline.g, root.md3Outline.b, 0.42))
        }

        background: Rectangle {
            implicitWidth: listSb.orientation === Qt.Vertical ? 3 : listSb.availableWidth
            implicitHeight: listSb.orientation === Qt.Horizontal ? 3 : listSb.availableHeight
            radius: 1.5
            color: "transparent"
        }
    }

    component UiButton: Button {
        id: uiBtn
        property string tone: "outlined" // filled | tonal | outlined | text
        property bool danger: false
        property bool compact: false

        implicitHeight: compact ? 30 : root.controlHeight
        implicitWidth: compact ? 76 : 110
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        flat: true
        font.pixelSize: compact ? 12 : 13
        font.weight: Font.Medium

        contentItem: Text {
            text: uiBtn.text
            font: uiBtn.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: {
                if (uiBtn.danger) {
                    if (uiBtn.tone === "filled") return root.md3OnError;
                    return root.md3Error;
                }
                if (uiBtn.tone === "filled") return root.md3OnPrimary;
                if (uiBtn.tone === "tonal") return root.md3OnPrimaryContainer;
                return root.md3OnSurface;
            }
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: compact ? 14 : root.controlRadius
            border.width: uiBtn.tone === "outlined" ? 1 : 0
            border.color: uiBtn.danger ? Qt.rgba(root.md3Error.r, root.md3Error.g, root.md3Error.b, 0.35) : root.md3OutlineVariant
            color: {
                if (uiBtn.tone === "filled") {
                    if (uiBtn.danger) {
                        return uiBtn.down ? Qt.darker(root.md3Error, 1.08) : (uiBtn.hovered ? Qt.darker(root.md3Error, 1.04) : root.md3Error);
                    }
                    return uiBtn.down ? Qt.darker(root.md3Primary, 1.08) : (uiBtn.hovered ? Qt.darker(root.md3Primary, 1.04) : root.md3Primary);
                }
                if (uiBtn.tone === "tonal") {
                    return uiBtn.down
                        ? Qt.darker(root.md3PrimaryContainer, 1.08)
                        : (uiBtn.hovered ? Qt.darker(root.md3PrimaryContainer, 1.04) : root.md3PrimaryContainer);
                }
                if (uiBtn.tone === "text") {
                    if (uiBtn.danger) {
                        return uiBtn.hovered ? Qt.rgba(root.md3Error.r, root.md3Error.g, root.md3Error.b, 0.22) : "transparent";
                    }
                    return uiBtn.hovered ? root.hoverOverlay(true) : "transparent";
                }
                return uiBtn.hovered ? Qt.rgba(root.md3OnSurface.r, root.md3OnSurface.g, root.md3OnSurface.b, 0.04) : "transparent";
            }
            Behavior on color { ColorAnimation { duration: 110 } }
        }
    }

    component UiCard: Rectangle {
        radius: root.shapeMedium
        color: root.md3SurfaceContainerLow
        border.width: 0
    }

    component UiSlider: Slider {
        id: s
        focusPolicy: Qt.NoFocus
        implicitHeight: 26

        background: Rectangle {
            x: s.leftPadding
            y: s.topPadding + s.availableHeight / 2 - height / 2
            width: s.availableWidth
            height: 4
            radius: 2
            color: root.md3OutlineVariant

            Rectangle {
                width: s.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.md3Primary
            }
        }

        handle: Rectangle {
            x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
            y: s.topPadding + s.availableHeight / 2 - height / 2
            width: 14
            height: 14
            radius: 7
            color: s.pressed ? Qt.darker(root.md3Primary, 1.1) : root.md3Primary
            border.width: 0
        }
    }


    component UiComboBox: ComboBox {
        id: cb
        focusPolicy: Qt.NoFocus
        implicitHeight: root.controlHeight
        font.pixelSize: 13
        leftPadding: 16
        rightPadding: 30
        property int horizontalAlignment: Text.AlignLeft
        
        indicator: Item {
            x: cb.width - width - 6
            y: cb.topPadding + (cb.availableHeight - height) / 2
            width: 28
            height: 20
            z: 3

            IconImage {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: cb.popup && cb.popup.visible
                    ? "qrc:/qt/qml/visualization for hexo/assets/iconpark/up.svg"
                    : "qrc:/qt/qml/visualization for hexo/assets/iconpark/down.svg"
                color: cb.pressed ? root.md3Primary : root.md3OnSurfaceVariant
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                propagateComposedEvents: false
                onClicked: {
                    if (!cb.popup) return;
                    if (cb.popup.visible) {
                        cb.popup.close();
                    } else {
                        cb.popup.open();
                    }
                }
            }
        }
        
        delegate: ItemDelegate {
            width: cb.width
            height: root.menuItemHeight
            horizontalPadding: 12
            font.pixelSize: 13
            contentItem: Text {
                text: modelData
                color: cb.currentIndex === index ? root.md3Primary : root.md3OnSurface
                font: cb.font
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                color: highlighted ? Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, 0.08) : "transparent"
                radius: root.shapeSmall
            }
        }

        popup: Popup {
            y: cb.height + 6
            width: cb.width
            padding: 6
            implicitHeight: Math.min(contentItem.contentHeight + topPadding + bottomPadding, root.menuItemHeight * 4 + 12)
            transformOrigin: Item.Top

            enter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
                }
            }
            exit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 90; easing.type: Easing.InCubic }
                    NumberAnimation { property: "scale"; from: 1.0; to: 0.98; duration: 90; easing.type: Easing.InCubic }
                }
            }

            background: Rectangle {
                radius: root.shapeMedium
                color: root.md3SurfaceContainerLowest
                border.width: 1
                border.color: root.md3OutlineVariant
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: cb.popup.visible ? cb.delegateModel : null
                currentIndex: cb.highlightedIndex
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                ScrollBar.vertical: PageScrollBar {}
            }
        }

        contentItem: Loader {
            anchors.fill: parent
            anchors.leftMargin: cb.leftPadding
            anchors.rightMargin: cb.rightPadding
            anchors.topMargin: cb.topPadding
            anchors.bottomMargin: cb.bottomPadding
            sourceComponent: cb.editable ? editableComboContent : readonlyComboContent
        }

        Component {
            id: editableComboContent
            TextInput {
                id: editableInput
                anchors.fill: parent
                leftPadding: 0
                rightPadding: 0
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: cb.horizontalAlignment
                text: cb.editText
                font: cb.font
                color: root.md3OnSurface
                selectByMouse: true

                onTextEdited: {
                    if (cb.editText !== text) {
                        cb.editText = text
                    }
                }

                Connections {
                    target: cb
                    function onEditTextChanged() {
                        if (editableInput.text !== cb.editText) {
                            editableInput.text = cb.editText
                        }
                    }
                }
            }
        }

        Component {
            id: readonlyComboContent
            Text {
                anchors.fill: parent
                text: cb.displayText
                font: cb.font
                color: root.md3OnSurface
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: cb.horizontalAlignment
                elide: Text.ElideRight
            }
        }
        
        background: Rectangle {
            implicitWidth: 120
            implicitHeight: cb.implicitHeight
            radius: root.shapeSmall
            color: cb.hovered ? root.md3SurfaceContainerHigh : root.md3SurfaceContainerLow
            border.width: (cb.visualFocus || (cb.popup && cb.popup.visible)) ? 2 : 1
            border.color: (cb.visualFocus || (cb.popup && cb.popup.visible)) ? root.md3FocusSoft : root.md3OutlineVariant

            Behavior on border.color { ColorAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    component UiTextField: TextField {
        id: tf
        focusPolicy: Qt.StrongFocus
        implicitHeight: root.inputHeight
        font.pixelSize: 13
        color: root.md3OnSurface
        selectedTextColor: root.md3OnPrimary
        selectionColor: root.md3Primary
        
        background: Rectangle {
            radius: root.shapeSmall
            color: root.md3SurfaceContainerLow
            border.width: tf.activeFocus ? 2 : 1
            border.color: tf.activeFocus ? root.md3FocusSoft : root.md3OutlineVariant
            
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    component UiSwitch: Switch {
        id: sw
        focusPolicy: Qt.NoFocus
        
        indicator: Rectangle {
            implicitWidth: 46
            implicitHeight: 26
            x: sw.leftPadding
            y: parent.height / 2 - height / 2
            radius: 13
            color: sw.checked ? root.md3Primary : root.md3SurfaceContainerHighest
            border.width: sw.checked ? 0 : 2
            border.color: sw.checked ? root.md3Primary : root.md3Outline
            
            Rectangle {
                x: sw.checked ? parent.width - width - 4 : 4
                y: 4
                width: 18
                height: 18
                radius: 9
                color: sw.checked ? root.md3OnPrimary : root.md3Outline
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            }
        }
        
        contentItem: Text {
            text: sw.text
            font.pixelSize: 13
            color: root.md3OnSurface
            leftPadding: sw.indicator.width + sw.spacing
            verticalAlignment: Text.AlignVCenter
        }
    }

    component StatusTag: Rectangle {
        property string label: ""
        property bool ok: false
        implicitWidth: statusRow.implicitWidth + 14
        implicitHeight: 26
        radius: 13
        color: ok
            ? Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, 0.12)
            : Qt.rgba(root.md3Error.r, root.md3Error.g, root.md3Error.b, 0.10)

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 6

            IconImage {
                width: 14
                height: 14
                source: ok ? root.iconBase + "HugeiconsCheckmarkCircle02.svg" : root.iconBase + "close.svg"
                color: ok ? root.md3Primary : root.md3Error
            }

            Text {
                text: label
                font.pixelSize: 12
                font.weight: Font.Medium
                color: ok ? root.md3Primary : root.md3Error
            }
        }
    }

    // Helper: onSurfaceVariant hover overlay
    function hoverOverlay(hovered) {
        return hovered
            ? Qt.rgba(md3OnSurfaceVariant.r, md3OnSurfaceVariant.g, md3OnSurfaceVariant.b, 0.08)
            : "transparent"
    }

    // ======================== App Logic ========================
    function translateCfgKey(k) {
        var dict = {
            "title": "网站标题",
            "subtitle": "副标题",
            "description": "网站描述",
            "keywords": "关键词",
            "author": "作者",
            "language": "语言",
            "timezone": "时区",
            "url": "站点地址",
            "theme": "主题",
            "type": "部署方式",
            "repo": "部署仓库",
            "branch": "部署分支",
            "display_mode": "显示模式",
            "index_layout": "首页布局",
            "post_pagination": "文章分页",
            "rightside_scroll_percent": "右下角滚动百分比",
            "rightside_config_animation": "右下角按钮动画",
            "readmode": "阅读模式",
            "photofigcaption": "图片标题",
            "enter_transitions": "页面过渡",
            "css_prefix": "CSS 前缀",
            "structured_data": "结构化数据",
            "pjax": "PJAX",
            "instantpage": "Instant.page",
            "disable_top_img": "禁用横幅图",
            "footer_img": "页脚背景图"
        };
        return dict[k] || (k + " (原键)");
    }

    function refreshConfigRows() {
        configModel.clear();
        var cfg = appContext.configMap;
        if (!cfg) return;
        var keys = [];
        if (root.settingsTabIndex === 1) {
            keys = ["title", "subtitle", "description", "keywords", "author", "language", "timezone", "url"];
        } else {
            keys = Object.keys(cfg);
            keys.sort();
        }
        for (var i = 0; i < keys.length; i++) {
            if (cfg[keys[i]] === undefined)
                continue;
            var val = String(cfg[keys[i]]);
            configModel.append({
                rawKey: keys[i],
                displayKey: root.translateCfgKey(keys[i]),
                value: val
            });
        }
    }

    function parsePostDate(raw) {
        if (!raw)
            return null;
        var s = String(raw).trim();
        if (s.length === 0)
            return null;
        var m = s.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T\s](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$/);
        if (!m)
            return null;
        return new Date(
            Number(m[1]),
            Number(m[2]) - 1,
            Number(m[3]),
            Number(m[4] || 0),
            Number(m[5] || 0),
            Number(m[6] || 0)
        );
    }

    function refreshTopicStats() {
        var posts = appContext.posts || [];
        var categorySet = {};
        var tagSet = {};
        var categoryCountMap = {};
        var tagCountMap = {};
        var monthlyCountMap = {};
        var dated = [];
        var palette = ["#5B8FF9", "#5AD8A6", "#5D7092", "#F6BD16", "#E8684A", "#6DC8EC", "#9270CA", "#FF9D4D"];

        function pushCount(mapObj, key) {
            if (!mapObj[key])
                mapObj[key] = 0;
            mapObj[key] += 1;
        }

        function monthLabel(d) {
            var y = d.getFullYear();
            var m = d.getMonth() + 1;
            return y + "-" + (m < 10 ? "0" + m : m);
        }

        for (var i = 0; i < posts.length; i++) {
            var p = posts[i] || {};
            var categoryRaw = String(p.category || "");
            var tagRaw = String(p.tags || "");

            var categories = categoryRaw.split(/[,，]/);
            for (var c = 0; c < categories.length; c++) {
                var cat = categories[c].trim();
                if (cat.length > 0) {
                    categorySet[cat] = true;
                    pushCount(categoryCountMap, cat);
                }
            }

            var tags = tagRaw.replace(/[\[\]]/g, "").split(/[,，]/);
            for (var t = 0; t < tags.length; t++) {
                var tag = tags[t].trim();
                if (tag.length > 0) {
                    tagSet[tag] = true;
                    pushCount(tagCountMap, tag);
                }
            }

            var d = root.parsePostDate(p.date);
            if (d) {
                dated.push(d);
                pushCount(monthlyCountMap, monthLabel(d));
            }
        }

        dated.sort(function(a, b) { return b.getTime() - a.getTime(); });

        var updateFrequency = "样本不足";
        if (dated.length >= 2) {
            var limit = Math.min(dated.length - 1, 10);
            var sumDays = 0;
            var used = 0;
            for (var j = 0; j < limit; j++) {
                var deltaMs = dated[j].getTime() - dated[j + 1].getTime();
                if (deltaMs > 0) {
                    sumDays += deltaMs / 86400000;
                    used++;
                }
            }

            if (used > 0) {
                var avgDays = sumDays / used;
                if (avgDays <= 1.2)
                    updateFrequency = "约每日更新";
                else if (avgDays <= 3)
                    updateFrequency = "约每 2-3 天";
                else if (avgDays <= 7)
                    updateFrequency = "约每周更新";
                else if (avgDays <= 14)
                    updateFrequency = "约双周更新";
                else
                    updateFrequency = "约每 " + Math.round(avgDays) + " 天更新";
            }
        }

        var categoryTop = Object.keys(categoryCountMap).map(function(k) {
            return { name: k, value: categoryCountMap[k] };
        });
        categoryTop.sort(function(a, b) { return b.value - a.value; });
        categoryTop = categoryTop.slice(0, 6);
        for (var cidx = 0; cidx < categoryTop.length; cidx++) {
            categoryTop[cidx].color = palette[cidx % palette.length];
        }

        var tagTop = Object.keys(tagCountMap).map(function(k) {
            return { name: k, value: tagCountMap[k] };
        });
        tagTop.sort(function(a, b) { return b.value - a.value; });
        tagTop = tagTop.slice(0, 6);
        for (var tidx = 0; tidx < tagTop.length; tidx++) {
            tagTop[tidx].color = palette[tidx % palette.length];
        }

        var trend = [];
        var now = new Date();
        var trendMax = 1;
        for (var m = 5; m >= 0; m--) {
            var d0 = new Date(now.getFullYear(), now.getMonth() - m, 1);
            var key = monthLabel(d0);
            var val = Number(monthlyCountMap[key] || 0);
            if (val > trendMax)
                trendMax = val;
            trend.push({ label: String(d0.getMonth() + 1) + "月", value: val });
        }

        root.topicStats = {
            categoryCount: Object.keys(categorySet).length,
            tagCount: Object.keys(tagSet).length,
            updateFrequency: updateFrequency,
            categoryTop: categoryTop,
            tagTop: tagTop,
            trend: trend,
            trendMax: trendMax
        };
    }

    onSettingsTabIndexChanged: {
        root.refreshConfigRows()
        if (root.settingsTabIndex === 4) {
            appContext.scanTrash()
        }
        if (root.settingsTabIndex === 2) {
            root.backupHistory = appContext.gitLogSync(20)
        }
    }

    Connections {
        target: appContext
        onConfigMapChanged: root.refreshConfigRows()
        onPostsChanged: root.refreshTopicStats()
        function onCurrentProjectPathChanged() {
            root.refreshTopicStats()
        }
    }

    Connections {
        target: appContext
        function onOpenedPostChanged() {
            if (dateInput) {
                dateInput.editText = appContext.openedPostDate
            }
        }
    }

    Connections {
        target: appContext
        function onLogTextChanged() {
            if (root.pluginDialogPending) {
                var rawOutput = appContext.logText.substring(root.pluginLogStart)
                var lines = rawOutput.split('\n')
                var cleanLines = lines.filter(function(l) {
                    var t = l.trim()
                    return t.length > 0
                        && !l.startsWith('$ ')
                        && !l.startsWith('[task finished]')
                        && !/^[─\s]+$/.test(t)
                })
                pluginResultDialog.outputText = cleanLines.join('\n').trim()
            }
        }
        function onTaskRunningChanged() {
            if (!appContext.taskRunning && root.pluginDialogPending) {
                root.pluginDialogPending = false
                var rawOutput = appContext.logText.substring(root.pluginLogStart)
                var exitMatch = rawOutput.match(/\[task finished\] exit=(-?\d+)/)
                root.pluginDialogExitCode = exitMatch ? parseInt(exitMatch[1]) : -1
                var lines = rawOutput.split('\n')
                var cleanLines = lines.filter(function(l) {
                    var t = l.trim()
                    return t.length > 0
                        && !l.startsWith('$ ')
                        && !l.startsWith('[task finished]')
                        && !/^[─\s]+$/.test(t)
                })
                pluginResultDialog.outputText = cleanLines.join('\n').trim()
            }
        }
    }

    Component.onCompleted: {
        root.normalWindowX = root.x
        root.normalWindowY = root.y
        root.normalWindowWidth = root.width
        root.normalWindowHeight = root.height
        root.maximizeToggleActive =
            root.visibility === Window.Maximized
            || root.visibility === Window.FullScreen
            || ((root.windowState & Qt.WindowMaximized) !== 0)
            || ((root.windowState & Qt.WindowFullScreen) !== 0)
        root.refreshConfigRows();
        root.previewMarkdownSource = "";
        root.envStatus = appContext.environmentCheck();
        root.diagnosticsText = JSON.stringify(appContext.diagnosticsReport(), null, 2)
        root.refreshTopicStats();
        if (root.contentItem) {
            root.contentItem.layer.enabled = root.resizeDegrade
            root.contentItem.layer.smooth = true
            root.contentItem.layer.mipmap = true
        }
        Qt.callLater(function() {
            root.bindOpenedPostFields()
        })
        if (appContext.firstRun) {
            firstRunDialog.open()
        }
    }

    ListModel { id: configModel }

    Timer {
        id: envStatusTimer
        interval: 2000
        repeat: false
        onTriggered: root.envStatusVisible = false
    }

    Timer {
        id: resizeSettleTimer
        interval: 120
        repeat: false
        onTriggered: {
            root.resizeDegrade = false
            if (editorContent && editorContent.isMarkdown) {
                previewRenderTimer.restart()
            }
        }
    }

    Timer {
        id: geometryTransitionTimer
        interval: 180
        repeat: false
        onTriggered: {
            root.suppressResizeDegrade = false
            root.resizeDegrade = false
            if (editorScrollView) {
                editorScrollView.returnToBounds()
            }
            if (editorContent && editorContent.isMarkdown) {
                previewRenderTimer.restart()
            }
        }
    }

    Timer {
        id: windowStateRefreshTimer
        interval: 24
        repeat: false
        onTriggered: {
            root.suppressResizeDegrade = false
            root.resizeDegrade = false
            root.forceMainLayoutSync()
            windowStateRefreshTailTimer.restart()
        }
    }

    Timer {
        id: windowStateRefreshTailTimer
        interval: 96
        repeat: false
        onTriggered: {
            root.forceMainLayoutSync()
        }
    }

    Timer {
        id: autoSaveTimer
        interval: 2000
        repeat: false
        onTriggered: root.doAutoSave()
    }

    Timer {
        id: autoSaveStatusFade
        interval: 2000
        repeat: false
        onTriggered: root.autoSaveStatus = ""
    }

    Timer {
        id: searchDebounceTimer
        interval: 280
        repeat: false
        onTriggered: {
            var q = root.sidebarSearchQuery.trim()
            if (q.length > 0) {
                appContext.search(q)
            }
        }
    }

    // ======================== MD3 Top App Bar ========================
    Rectangle {
        id: titleBar
        visible: !root.isWindowFullScreen
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? 52 : 0
        color: root.md3SurfaceContainerLowest
        z: 10

        // Bottom divider
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0, 0, 0, 0.06) }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 4

            Row {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 14
                spacing: 10

                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: "#FF5F57"
                        border.width: 1
                        border.color: "#E04842"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: "#FFBD2E"
                        border.width: 1
                        border.color: "#DEA123"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showMinimized()
                        }
                    }

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: "#28C840"
                        border.width: 1
                        border.color: "#18A42E"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleMaximizeRestore()
                        }
                    }
                }

            }

            Item { Layout.fillWidth: true }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 12

                Rectangle {
                    id: taskIndicatorInline
                    visible: appContext.taskRunning
                    width: taskRunningRowInline.implicitWidth + 22
                    height: 28
                    radius: 14
                    color: "#FFF3E0"
                    border.width: 1
                    border.color: "#FFD3A4"

                    Row {
                        id: taskRunningRowInline
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 7
                            radius: 3.5
                            color: "#E65100"
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600 }
                                NumberAnimation { to: 1.0; duration: 600 }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "任务运行中..."
                            color: "#E65100"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }

                // ---- Preview button (MD3 Tonal) ----
                UiButton {
                    text: "预览"
                    tone: "tonal"
                    compact: true
                    implicitWidth: 72
                    implicitHeight: root.topBarButtonSize
                    onClicked: {
                        root.consoleVisible = true
                        appContext.appendStructuredLog("info", "PREVIEW_CLICK", "requested: hexo server")
                        if (!appContext.currentProjectPath || appContext.currentProjectPath.length === 0) {
                            appContext.appendStructuredLog("warn", "PREVIEW_NO_PROJECT", "请先选择 Hexo 项目后再预览")
                            return
                        }
                        var env = appContext.environmentCheck()
                        if (!env.hexo) {
                            appContext.appendStructuredLog("warn", "PREVIEW_NO_HEXO", "未检测到 hexo 命令，请先安装并配置环境")
                        }
                        appContext.runHexoServer()
                    }
                }

                // ---- Publish button (MD3 Filled) ----
                UiButton {
                    text: "发布"
                    tone: "filled"
                    compact: true
                    implicitWidth: 72
                    implicitHeight: root.topBarButtonSize
                    onClicked: {
                        if (!appContext.currentProjectPath || appContext.currentProjectPath.length === 0) {
                            appContext.appendStructuredLog("warn", "DEPLOY_NO_PROJECT", "请先选择 Hexo 项目后再发布")
                            return
                        }
                        root.showConfirmDialog(
                            "发布站点",
                            "确定要执行 hexo deploy 吗？这将把当前站点发布到线上。",
                            "发布",
                            false,
                            function() {
                                root.consoleVisible = true
                                appContext.appendStructuredLog("info", "DEPLOY_CLICK", "requested: hexo deploy")
                                var env = appContext.environmentCheck()
                                if (!env.hexo || !env.git) {
                                    appContext.appendStructuredLog("warn", "DEPLOY_ENV", "发布依赖 hexo 和 git，请检查环境")
                                }
                                appContext.runHexoDeploy()
                            }
                        )
                    }
                }

                // ---- Settings button ----
                IconActionButton {
                    width: root.topBarButtonSize
                    height: root.topBarButtonSize
                    iconSource: root.iconBase + "setting.svg"
                    toolTipText: "设置"
                    onClicked: {
                        if (settingsDrawer.opened) {
                            settingsDrawer.close()
                        } else {
                            settingsDrawer.open()
                        }
                    }
                }
                
            }
        }

    }

    // ======================== Main Content ========================
    SplitView {
        id: mainContentSplit
        anchors.top: root.isWindowFullScreen ? parent.top : titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        orientation: Qt.Horizontal

        handle: Item {
            id: mainSplitHandle
            implicitWidth: 0
        }

        // ==================== Left Sidebar (Posts List) ====================
        Rectangle {
            id: sidebar
            SplitView.preferredWidth: root.fixedSidebarWidth
            SplitView.minimumWidth: root.fixedSidebarWidth
            SplitView.maximumWidth: root.fixedSidebarWidth
            color: root.sidePanelBg
            visible: true

            StackLayout {
                id: sidebarStack
                anchors.fill: parent
                currentIndex: aiUi.editMode ? 1 : 0

                ColumnLayout {
                    spacing: 0

                    // Sidebar header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 12

                            Text {
                                text: "文章"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: root.md3OnSurface
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                visible: !root.sidebarSearchMode
                            }

                            UiTextField {
                                id: searchInput
                                visible: root.sidebarSearchMode
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                height: root.inputHeight
                                placeholderText: "搜索文章标题、内容..."
                                onTextChanged: {
                                    root.sidebarSearchQuery = text
                                    searchDebounceTimer.restart()
                                }
                            }

                            IconActionButton {
                                Layout.alignment: Qt.AlignVCenter
                                width: 28
                                height: 28
                                iconSource: root.iconBase + "search.svg"
                                toolTipText: root.sidebarSearchMode ? "关闭搜索" : "搜索文章"
                                background: Rectangle {
                                    radius: root.shapeSmall
                                    color: root.sidebarSearchMode
                                        ? root.md3PrimaryContainer
                                        : (parent.pressed
                                            ? Qt.rgba(root.md3OnSurfaceVariant.r, root.md3OnSurfaceVariant.g, root.md3OnSurfaceVariant.b, 0.18)
                                            : (parent.hovered ? root.hoverOverlay(true) : "transparent"))
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                contentItem: Item {
                                    IconImage {
                                        anchors.centerIn: parent
                                        width: 15
                                        height: 15
                                        source: root.iconBase + (root.sidebarSearchMode ? "close.svg" : "search.svg")
                                        color: root.sidebarSearchMode ? root.md3Primary : root.md3OnSurfaceVariant
                                    }
                                }
                                onClicked: {
                                    root.sidebarSearchMode = !root.sidebarSearchMode
                                    if (!root.sidebarSearchMode) searchInput.text = ""
                                }
                            }
                        }
                    }

                // Posts list
                ListView {
                    id: postsList
                    visible: !root.sidebarSearchMode
                    property real quantizedWidth: Math.max(320, Math.round(width / 20) * 20)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: appContext.posts
                    cacheBuffer: 720
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 13000
                    maximumFlickVelocity: 6400
                    ScrollBar.vertical: ListScrollBar {}

                    delegate: Item {
                        property var postEntry: modelData || ({})
                        width: ListView.view.width
                        height: 86

                        MouseArea {
                            id: postMouse
                            anchors.fill: parent
                            hoverEnabled: !root.resizeDegrade
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: {
                                if (postEntry.path) {
                                    appContext.openPost(postEntry.path)
                                }
                            }
                            onPressAndHold: {
                                if (postEntry.path) {
                                    root.showConfirmDialog(
                                        "删除文章",
                                        "确定要删除文章「" + (postEntry.title || "") + "」吗？删除后可在回收站中恢复。",
                                        "删除",
                                        true,
                                        (function(path) { return function() { appContext.deletePost(path) } })(postEntry.path)
                                    )
                                }
                            }

                            Rectangle {
                                id: postItemBg
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 4
                                anchors.bottomMargin: 4
                                radius: root.shapeMedium

                                color: {
                                    if (postEntry.path && postEntry.path === appContext.openedPostPath) return root.sidePanelItem
                                    if (postMouse.containsMouse) return Qt.rgba(root.md3OnSurface.r, root.md3OnSurface.g, root.md3OnSurface.b, 0.05)
                                    return "transparent"
                                }
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: 14

                                    Text {
                                        id: postTitle
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: deleteBtnContainer.left
                                        anchors.rightMargin: 8
                                        text: postEntry.title || ""
                                        font.pixelSize: 15
                                        font.weight: postEntry.path === appContext.openedPostPath ? Font.DemiBold : Font.Normal
                                        color: root.md3OnSurface
                                        elide: Text.ElideRight
                                    }

                                    Item {
                                        id: deleteBtnContainer
                                        anchors.top: parent.top
                                        anchors.topMargin: -4
                                        anchors.right: parent.right
                                        width: 44
                                        height: 32

                                        UiButton {
                                            id: deleteBtn
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "删除"
                                            tone: "text"
                                            danger: true
                                            compact: true
                                            visible: !!postEntry.path
                                            opacity: (postMouse.containsMouse || (postEntry.path === appContext.openedPostPath)) ? 1 : 0
                                            enabled: opacity > 0.5
                                            Behavior on opacity { NumberAnimation { duration: 100 } }
                                            onClicked: {
                                                root.showConfirmDialog(
                                                    "删除文章",
                                                    "确定要删除文章「" + (postEntry.title || "") + "」吗？删除后可在回收站中恢复。",
                                                    "删除",
                                                    true,
                                                    (function(path) { return function() { appContext.deletePost(path) } })(postEntry.path)
                                                )
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        text: (postEntry.date || "") + (postEntry.category ? " · " + postEntry.category : "")
                                        font.pixelSize: 13
                                        color: root.md3OnSurfaceVariant
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // Search results (visible when search mode is active)
                Item {
                    visible: root.sidebarSearchMode
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: root.sidebarSearchQuery.trim().length === 0
                        text: "请输入关键词搜索"
                        font.pixelSize: 14
                        color: root.md3OnSurfaceVariant
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.sidebarSearchQuery.trim().length > 0 && appContext.searchResults.length === 0
                        text: "未找到相关文章"
                        font.pixelSize: 14
                        color: root.md3OnSurfaceVariant
                    }

                    ListView {
                        id: searchResultsList
                        anchors.fill: parent
                        visible: root.sidebarSearchQuery.trim().length > 0 && appContext.searchResults.length > 0
                        clip: true
                        model: appContext.searchResults
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 13000
                        maximumFlickVelocity: 6400
                        ScrollBar.vertical: ListScrollBar {}

                        delegate: Item {
                            property var entry: modelData || ({})
                            width: ListView.view.width
                            height: 80

                            MouseArea {
                                id: searchItemMouse
                                anchors.fill: parent
                                hoverEnabled: !root.resizeDegrade
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (entry.path) {
                                        appContext.openPost(entry.path)
                                        root.sidebarSearchMode = false
                                        searchInput.text = ""
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 4
                                    anchors.bottomMargin: 4
                                    radius: root.shapeMedium
                                    color: {
                                        if (entry.path && entry.path === appContext.openedPostPath)
                                            return root.sidePanelItem
                                        if (searchItemMouse.containsMouse)
                                            return Qt.rgba(root.md3OnSurface.r, root.md3OnSurface.g, root.md3OnSurface.b, 0.05)
                                        return "transparent"
                                    }
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 14

                                        Text {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            text: entry.title || ""
                                            font.pixelSize: 15
                                            font.weight: entry.path === appContext.openedPostPath ? Font.DemiBold : Font.Normal
                                            color: root.md3OnSurface
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            text: (entry.category || "") + (entry.tags && entry.tags.length ? " · " + entry.tags : "")
                                            font.pixelSize: 13
                                            color: root.md3OnSurfaceVariant
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                }

                // AI Chat Panel (index 1)
                AiChatPanel {
                    aiSession: aiSession
                    aiUi: aiUi
                    md3Primary: root.md3Primary
                    md3OnPrimary: root.md3OnPrimary
                    md3PrimaryContainer: root.md3PrimaryContainer
                    md3OnPrimaryContainer: root.md3OnPrimaryContainer
                    md3Surface: root.md3Surface
                    md3OnSurface: root.md3OnSurface
                    md3SurfaceContainer: root.md3SurfaceContainer
                    md3SurfaceContainerHigh: root.md3SurfaceContainerHigh
                    md3OnSurfaceVariant: root.md3OnSurfaceVariant
                    md3OutlineVariant: root.md3OutlineVariant
                    md3Error: root.md3Error
                    md3ErrorContainer: root.md3ErrorContainer
                    shapeMedium: root.shapeMedium
                    onCloseRequested: root.exitAiEditMode()
                    onApplyAllRequested: {
                        if (!aiSession.pendingDiff) return
                        var rebuilt = root.rebuildDiffBody(aiSession.pendingDiff.original, aiSession.pendingDiff.hunks, null)
                        appContext.applyAiEditedBody(rebuilt)
                        aiSession.pendingDiff = null
                        aiSession.hunkDecisions = ({})
                    }
                    onRejectAllRequested: {
                        aiSession.pendingDiff = null
                        aiSession.hunkDecisions = ({})
                    }
                    onApplyChangesRequested: {
                        if (!aiSession.pendingDiff) return
                        var rebuilt = root.rebuildDiffBody(aiSession.pendingDiff.original, aiSession.pendingDiff.hunks, aiSession.hunkDecisions)
                        appContext.applyAiEditedBody(rebuilt)
                        aiSession.pendingDiff = null
                        aiSession.hunkDecisions = ({})
                    }
                }
            }
        }

        // ==================== Center Area (Editor + Console Overlay) ====================
        Item {
            id: centerContentPane
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            // ---- Editor Area ----
            Rectangle {
                anchors.fill: parent
                color: root.layoutBg

                Item {
                    id: editorViewport
                    anchors.fill: parent
                    clip: true

                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        text: root.autoSaveStatus
                        font.pixelSize: 11
                        color: root.md3OnSurfaceVariant
                        opacity: root.autoSaveStatus.length > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    Flickable {
                        id: editorScrollView
                        anchors.fill: parent
                        clip: true
                        interactive: !root.degradeRendering
                        contentWidth: width
                        contentHeight: editorContent.implicitHeight + 24
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 12000
                        ScrollBar.vertical: PageScrollBar {}
                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                        Column {
                            id: editorContent
                            property bool isMarkdown: true
                            width: root.editorContentWidth()
                            x: Math.max(24, (editorScrollView.width - width) / 2)
                            y: 32
                            spacing: 20

                        // Title input
                        TextInput {
                            id: titleInput
                            width: parent.width
                            font.pixelSize: root.uiTitleFontSize
                            font.weight: Font.Medium
                            font.family: "SimSun"
                            color: root.readingInk
                            text: appContext.openedPostTitle
                            wrapMode: TextInput.Wrap
                            selectByMouse: true
                            onTextChanged: root.triggerAutoSave()
                        }

                        // Metadata card
                        Rectangle {
                            width: parent.width
                            height: metaCardCol.implicitHeight + 24
                            radius: root.shapeMedium
                            color: root.sidePanelItem
                            border.width: 0

                            ColumnLayout {
                                id: metaCardCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "分类"
                                        color: root.md3OnSurfaceVariant
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        Layout.preferredWidth: 38
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                    UiComboBox {
                                        id: categoryInput
                                        editable: true
                                        model: appContext.allCategories
                                        editText: appContext.openedPostCategory
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        onEditTextChanged: root.triggerAutoSave()
                                    }

                                    Text {
                                        text: "标签"
                                        color: root.md3OnSurfaceVariant
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        Layout.preferredWidth: 38
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                    UiComboBox {
                                        id: tagsInput
                                        editable: true
                                        model: appContext.allTags
                                        editText: appContext.openedPostTags
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        onEditTextChanged: root.triggerAutoSave()
                                    }

                                    Text {
                                        text: "时间"
                                        color: root.md3OnSurfaceVariant
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        Layout.preferredWidth: 38
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                    UiComboBox {
                                        id: dateInput
                                        editable: true
                                        model: []
                                        editText: appContext.openedPostDate
                                        spacing: 0
                                        horizontalAlignment: Text.AlignHCenter
                                        leftPadding: 12
                                        rightPadding: 12
                                        indicator: Item {
                                            width: 0
                                            height: 0
                                        }
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        onEditTextChanged: root.triggerAutoSave()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text { text: "封面"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; font.weight: Font.Medium; Layout.preferredWidth: 38 }
                                    UiTextField {
                                        id: coverInput
                                        Layout.fillWidth: true
                                        text: appContext.openedPostCover
                                        placeholderText: "/images/cover.jpg 或完整 URL"
                                        onTextChanged: {
                                            if (editorContent && editorContent.isMarkdown && !root.degradeRendering) {
                                                previewRenderTimer.restart()
                                            }
                                            root.triggerAutoSave()
                                        }
                                    }
                                    UiButton {
                                        text: "选择图片"
                                        tone: "outlined"
                                        onClicked: coverFileDialog.open()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text { text: "描述"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; font.weight: Font.Medium; Layout.preferredWidth: 38 }
                                    UiTextField {
                                        id: descriptionInput
                                        Layout.fillWidth: true
                                        text: appContext.openedPostDescription
                                        placeholderText: "文章摘要（为空时保存将自动生成）"
                                        onTextChanged: root.triggerAutoSave()
                                    }
                                    UiButton {
                                        text: "生成描述"
                                        tone: "tonal"
                                        onClicked: {
                                            var generated = appContext.generateDescriptionText(titleInput.text, bodyEdit.text)
                                            if (generated && generated.length > 0) {
                                                descriptionInput.text = generated
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle { width: parent.width; height: 1; color: root.md3OutlineVariant }

                        // Sticky diff header (visible when AI proposes changes)
                        Rectangle {
                            width: parent.width
                            height: visible ? diffHeaderRow.implicitHeight + 16 : 0
                            visible: aiSession && aiSession.pendingDiff !== null
                            color: Qt.rgba(0.106, 0.431, 0.953, 0.06)
                            z: 10

                            RowLayout {
                                id: diffHeaderRow
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: 10

                                Text {
                                    text: {
                                        var count = aiSession && aiSession.pendingDiff ? aiSession.pendingDiff.hunks.filter(function(h) { return h.type !== "equal" }).length : 0
                                        return "AI 修改建议 · " + count + " 处"
                                    }
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: root.md3OnSurface
                                    Layout.fillWidth: true
                                }

                                // Apply decided
                                Rectangle {
                                    width: diffApplyLabel.implicitWidth + 20
                                    height: 28
                                    radius: 14
                                    color: root.hasAnyDiffDecision ? root.md3Primary : root.md3OutlineVariant

                                    Text {
                                        id: diffApplyLabel
                                        anchors.centerIn: parent
                                        text: root.diffDecidedCount < root.diffChangeCount
                                            ? "应用 (" + root.diffDecidedCount + "/" + root.diffChangeCount + ")"
                                            : "应用全部"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: root.hasAnyDiffDecision ? root.md3OnPrimary : root.md3OnSurfaceVariant
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: root.hasAnyDiffDecision ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onClicked: {
                                            if (root.hasAnyDiffDecision && aiSession.pendingDiff) {
                                                var rebuilt = root.rebuildDiffBody(aiSession.pendingDiff.original, aiSession.pendingDiff.hunks, aiSession.hunkDecisions)
                                                appContext.applyAiEditedBody(rebuilt)
                                                aiSession.pendingDiff = null
                                                aiSession.hunkDecisions = ({})
                                            }
                                        }
                                    }
                                }

                                // Reject all
                                Rectangle {
                                    width: diffRejectLabel.implicitWidth + 20
                                    height: 28
                                    radius: 14
                                    color: "transparent"
                                    border.width: 1
                                    border.color: root.md3OutlineVariant

                                    Text {
                                        id: diffRejectLabel
                                        anchors.centerIn: parent
                                        text: "全部拒绝"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: root.md3OnSurfaceVariant
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            aiSession.pendingDiff = null
                                            aiSession.hunkDecisions = ({})
                                        }
                                    }
                                }
                            }
                        }

                        // Editor body
                        StackLayout {
                            width: parent.width
                            height: root.editorBodyHeight()
                            currentIndex: aiSession.pendingDiff ? 2 : (editorContent.isMarkdown ? 1 : 0)

                            TextEdit {
                                id: bodyEdit
                                width: parent.width
                                font.pixelSize: root.uiBodyFontSize
                                font.family: "SimSun"
                                color: root.readingInk
                                text: appContext.openedPostBody
                                wrapMode: TextEdit.Wrap
                                renderType: TextEdit.NativeRendering
                                selectByMouse: true
                                readOnly: false
                                textFormat: TextEdit.PlainText
                                onTextChanged: {
                                    if (aiSession && aiSession.pendingDiff) return
                                    if (editorContent.isMarkdown && !root.degradeRendering) {
                                        previewRenderTimer.restart()
                                    }
                                    root.triggerAutoSave()
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 10

                                Image {
                                    id: coverPreview
                                    visible: !!root.previewCoverSource && root.previewCoverSource.length > 0
                                    width: parent.width
                                    fillMode: Image.PreserveAspectFit
                                    source: root.previewCoverSource
                                    asynchronous: true
                                    cache: false
                                    smooth: true
                                    sourceSize.width: Math.max(400, width)
                                    sourceSize.height: 560
                                    height: visible
                                        ? Math.min(340, Math.max(120, width * 0.5))
                                        : 0
                                }

                                MarkdownPreview {
                                    id: mdPreview
                                    width: parent.width
                                    markdownText: root.previewMarkdownSource
                                    bodyFontSize: root.uiBodyFontSize
                                    lineSpacing: root.uiLineSpacing
                                    onScrollRequested: (deltaY) => {
                                        if (!editorScrollView) return
                                        editorScrollView.flick(0, deltaY * 12)
                                    }
                                }
                            }

                            // Diff Review View (index 2)
                            Item {
                                DiffReviewView {
                                    width: parent.width
                                    height: parent.height
                                    pendingDiff: aiSession.pendingDiff
                                    hunkDecisions: aiSession.hunkDecisions
                                    md3Primary: root.md3Primary
                                    md3OnPrimary: root.md3OnPrimary
                                    md3PrimaryContainer: root.md3PrimaryContainer
                                    md3OnPrimaryContainer: root.md3OnPrimaryContainer
                                    md3OnSurface: root.md3OnSurface
                                    md3OnSurfaceVariant: root.md3OnSurfaceVariant
                                    md3OutlineVariant: root.md3OutlineVariant
                                    md3Error: root.md3Error
                                    md3SurfaceContainer: root.md3SurfaceContainer
                                    shapeMedium: root.shapeMedium
                                    onHunkDecisionChanged: function(hunkId, accepted) {
                                        var decs = {}
                                        for (var k in aiSession.hunkDecisions) decs[k] = aiSession.hunkDecisions[k]
                                        decs[hunkId] = accepted
                                        aiSession.hunkDecisions = decs
                                    }
                                }
                            }
                        }

                        }
                    }
                }
            }

            Timer {
                id: previewRenderTimer
                interval: root.previewDebounceMs
                repeat: false
                onTriggered: {
                    if (!root.degradeRendering && !root.resizeDegrade) {
                        root.syncPreviewText(true)
                    }
                }
            }

            Connections {
                target: appContext
                function onPostAboutToChange(oldPath) {
                    // Save the CURRENT post before switching away
                    autoSaveTimer.stop()
                    if (oldPath && oldPath.length > 0 && titleInput) {
                        appContext.saveOpenedPost(
                            titleInput.text,
                            categoryInput.editText,
                            tagsInput.editText,
                            dateInput.editText,
                            coverInput.text,
                            descriptionInput.text,
                            bodyEdit.text
                        )
                    }
                }
                function onOpenedPostPathChanged() {
                    // Cancel AI state on post switch
                    if (appContext.aiChat) appContext.aiChat.cancel()
                    aiSession.streaming = false
                    aiSession.streamingText = ""
                    aiSession.pendingDiff = null
                    aiSession.hunkDecisions = ({})
                    aiUi.referencedPosts = []
                }
                function onOpenedPostChanged() {
                    console.log("[main] onOpenedPostChanged")
                    root.bindOpenedPostFields()
                    if (editorContent && editorContent.isMarkdown) {
                        root.syncPreviewText(true)
                        mdPreview.beginContentSwitch()
                    }
                    Qt.callLater(function() {
                        editorScrollView.contentY = 0
                    })
                }
            }

        }
    }

    IconActionButton {
        id: sidebarToggle
        anchors.left: parent.left
        anchors.leftMargin: sidebar.visible ? (root.fixedSidebarWidth + 10) : 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: root.topBarButtonSize
        height: root.topBarButtonSize
        iconSource: root.iconBase + "MeteorIconsSidebar.svg"
        toolTipText: sidebar.visible ? "收起侧边栏" : "展开侧边栏"
        z: 18
        onClicked: {
            const nextVisible = !sidebar.visible
            sidebar.visible = nextVisible
            sidebar.SplitView.preferredWidth = nextVisible ? root.fixedSidebarWidth : 0
        }
    }

    IconActionButton {
        id: viewModeToggle
        anchors.left: sidebarToggle.right
        anchors.leftMargin: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: root.topBarButtonSize
        height: root.topBarButtonSize
        iconSource: editorContent.isMarkdown ? (root.iconBase + "code.svg") : (root.iconBase + "preview-open.svg")
        toolTipText: editorContent.isMarkdown ? "切换到源码" : "切换到预览"
        z: 18
        onClicked: root.articleViewMode = editorContent.isMarkdown ? 0 : 1
    }

    // ======================== Settings Drawer (MD3 Side Sheet) ========================
    Drawer {
        id: settingsDrawer
        edge: Qt.RightEdge
        y: titleBar.height
        width: 460
        height: root.height - titleBar.height

        Rectangle {
            anchors.fill: parent
            color: root.md3Surface

            Flickable {
                id: settingsViewport
                anchors.fill: parent
                contentWidth: width
                contentHeight: settingsContent.implicitHeight + 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 10000
                interactive: true
                ScrollBar.vertical: PageScrollBar {}

                ColumnLayout {
                    id: settingsContent
                    width: parent.width - 48
                    x: 24
                    y: 24
                    height: implicitHeight
                    spacing: 24

                    // ---- Header ----
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "配置中心"
                            font.pixelSize: 24
                            font.weight: Font.Medium
                            color: root.md3OnSurface
                            Layout.fillWidth: true
                        }
                        IconActionButton { iconSource: root.iconBase + "close.svg"; toolTipText: "关闭"; onClicked: settingsDrawer.close() }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: root.shapeLarge
                        color: root.md3SurfaceContainerLow

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: "transparent"

                                Image {
                                    anchors.fill: parent
                                    source: "qrc:/qt/qml/visualization for hexo/assets/app-icon.png"
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(30, 30)
                                }
                            }

                            Text {
                                text: root.title
                                font.pixelSize: 18
                                font.weight: Font.Medium
                                color: root.md3OnSurface
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: root.shapeLarge
                        color: root.md3SurfaceContainerLow

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                text: "控制台"
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                color: root.md3OnSurface
                                Layout.preferredWidth: 58
                            }

                            UiButton {
                                Layout.fillWidth: true
                                text: root.consoleVisible ? "隐藏控制台" : "显示控制台"
                                tone: root.consoleVisible ? "outlined" : "tonal"
                                compact: true
                                onClicked: root.toggleConsoleVisibility()
                            }
                        }
                    }

                    UiCard {
                        visible: root.consoleVisible
                        Layout.fillWidth: true
                        implicitHeight: 260
                        color: root.md3InverseSurface

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: root.shapeSmall
                                color: Qt.darker(root.md3InverseSurface, 1.1)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {
                                        text: "控制台日志"
                                        color: root.md3InverseOnSurface
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            ScrollView {
                                id: settingsConsoleScroll
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                ScrollBar.vertical: PageScrollBar {}
                                ScrollBar.horizontal: PageScrollBar {}

                                TextArea {
                                    id: settingsLogText
                                    readOnly: true
                                    text: appContext.logText
                                    color: root.md3InverseOnSurface
                                    font.family: "Consolas"
                                    font.pixelSize: 13
                                    textFormat: TextEdit.PlainText
                                    wrapMode: TextEdit.NoWrap
                                    selectByMouse: true
                                    selectByKeyboard: true
                                    persistentSelection: true
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    background: null
                                    opacity: 0.9
                                    onTextChanged: {
                                        Qt.callLater(function() {
                                            if (settingsConsoleScroll.contentItem) {
                                                settingsConsoleScroll.contentItem.contentY =
                                                    Math.max(0, settingsConsoleScroll.contentItem.contentHeight - settingsConsoleScroll.contentItem.height)
                                            }
                                        })
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: root.shapeSmall
                                color: Qt.darker(root.md3InverseSurface, 1.15)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 6

                                    Text {
                                        text: ">"
                                        color: root.md3InversePrimary
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        Layout.preferredWidth: 12
                                    }

                                    TextInput {
                                        id: settingsConsoleInput
                                        Layout.fillWidth: true
                                        color: root.md3InverseOnSurface
                                        font.family: "Consolas"
                                        font.pixelSize: 13
                                        selectByMouse: true
                                        clip: true
                                        text: ""

                                        onAccepted: {
                                            var cmd = text.trim()
                                            if (cmd.length > 0) {
                                                if (root.consoleCommandHistory.length === 0 || root.consoleCommandHistory[root.consoleCommandHistory.length - 1] !== cmd) {
                                                    root.consoleCommandHistory.push(cmd)
                                                }
                                                root.consoleHistoryIndex = -1
                                                appContext.submitConsoleInput(cmd)
                                                text = ""
                                            }
                                        }

                                        Keys.onUpPressed: {
                                            if (root.consoleCommandHistory.length === 0) return
                                            if (root.consoleHistoryIndex < 0) {
                                                root.consoleHistoryIndex = root.consoleCommandHistory.length - 1
                                            } else if (root.consoleHistoryIndex > 0) {
                                                root.consoleHistoryIndex -= 1
                                            }
                                            text = root.consoleCommandHistory[root.consoleHistoryIndex]
                                        }

                                        Keys.onDownPressed: {
                                            if (root.consoleCommandHistory.length === 0) return
                                            if (root.consoleHistoryIndex < 0) return
                                            root.consoleHistoryIndex += 1
                                            if (root.consoleHistoryIndex >= root.consoleCommandHistory.length) {
                                                root.consoleHistoryIndex = -1
                                                text = ""
                                            } else {
                                                text = root.consoleCommandHistory[root.consoleHistoryIndex]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 82
                        radius: root.shapeLarge
                        color: root.md3SurfaceContainerLow

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: "文章设置", icon: "edit.svg" },
                                    { label: "站点设置", icon: "setting.svg" },
                                    { label: "系统设置", icon: "code.svg" },
                                    { label: "信息统计", icon: "preview-open.svg" },
                                    { label: "回收站", icon: "delete.svg" }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumWidth: 0
                                    Layout.fillHeight: true
                                    radius: root.shapeMedium
                                    color: root.settingsTabIndex === index
                                        ? root.md3PrimaryContainer
                                        : root.md3SurfaceContainerLowest
                                    border.width: 1
                                    border.color: root.settingsTabIndex === index
                                        ? root.md3Primary
                                        : root.md3OutlineVariant

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: root.settingsTabIndex === index
                                                ? root.md3Primary
                                                : root.md3PrimaryContainer
                                            anchors.horizontalCenter: parent.horizontalCenter

                                            IconImage {
                                                anchors.centerIn: parent
                                                width: 14
                                                height: 14
                                                source: root.iconBase + modelData.icon
                                                color: root.settingsTabIndex === index
                                                    ? root.md3OnPrimary
                                                    : root.md3OnSurface
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            color: root.settingsTabIndex === index
                                                ? root.md3Primary
                                                : root.md3OnSurface
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.settingsTabIndex = index
                                    }
                                }
                            }
                        }
                    }

                    UiCard {
                        visible: root.settingsTabIndex === 0
                        Layout.fillWidth: true
                        implicitHeight: textDisplayCol.implicitHeight + 40

                        ColumnLayout {
                            id: textDisplayCol
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12

                            Text { text: "文字显示"; font.pixelSize: 16; font.weight: Font.DemiBold; color: root.md3OnSurface }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "标题字号"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; Layout.preferredWidth: 74 }
                                UiSlider {
                                    Layout.fillWidth: true
                                    live: false
                                    from: 22
                                    to: 40
                                    stepSize: 1
                                    value: root.uiTitleFontSize
                                    onValueChanged: root.uiTitleFontSize = Math.round(value)
                                }
                                Text { text: root.uiTitleFontSize + " px"; color: root.md3OnSurface; font.pixelSize: 13; Layout.preferredWidth: 52 }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "正文字号"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; Layout.preferredWidth: 74 }
                                UiSlider {
                                    Layout.fillWidth: true
                                    live: false
                                    from: 13
                                    to: 22
                                    stepSize: 1
                                    value: root.uiBodyFontSize
                                    onValueChanged: root.uiBodyFontSize = Math.round(value)
                                }
                                Text { text: root.uiBodyFontSize + " px"; color: root.md3OnSurface; font.pixelSize: 13; Layout.preferredWidth: 52 }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "行间距"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; Layout.preferredWidth: 74 }
                                UiSlider {
                                    Layout.fillWidth: true
                                    live: false
                                    from: 1.2
                                    to: 2.2
                                    stepSize: 0.05
                                    value: root.uiLineSpacing
                                    onValueChanged: root.uiLineSpacing = Math.round(value * 100) / 100
                                }
                                Text { text: root.uiLineSpacing.toFixed(2); color: root.md3OnSurface; font.pixelSize: 13; Layout.preferredWidth: 52 }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "文章排序"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; Layout.preferredWidth: 74 }
                                UiComboBox {
                                    Layout.fillWidth: true
                                    model: ["时间: 新到旧", "时间: 旧到新", "标题: A-Z", "标题: Z-A"]
                                    currentIndex: appContext.postSortMode
                                    onActivated: appContext.postSortMode = currentIndex
                                }
                            }
                        }
                    }

                    UiCard {
                        visible: root.settingsTabIndex === 2
                        Layout.fillWidth: true
                        implicitHeight: projectCol.implicitHeight + 40

                        ColumnLayout {
                            id: projectCol
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12

                            Text { text: "项目管理"; font.pixelSize: 16; font.weight: Font.DemiBold; color: root.md3OnSurface }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                UiCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 64
                                    color: root.md3SurfaceContainer

                                    Column {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        anchors.topMargin: 10
                                        spacing: 4

                                        Text {
                                            text: "当前项目"
                                            color: root.md3OnSurfaceVariant
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: appContext.currentProjectPath || "未选择"
                                            color: root.md3OnSurface
                                            font.pixelSize: 13
                                            elide: Text.ElideMiddle
                                            width: parent.width
                                        }
                                    }
                                }

                                UiCard {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: 64
                                    color: root.md3PrimaryContainer

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            text: "项目数"
                                            color: root.md3OnPrimaryContainer
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            width: 60
                                        }
                                        Text {
                                            text: String((appContext.projects || []).length)
                                            color: root.md3Primary
                                            font.pixelSize: 20
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            width: 60
                                        }
                                    }
                                }
                            }

                            UiCard {
                                Layout.fillWidth: true
                                color: root.md3SurfaceContainer
                                implicitHeight: projectOpsCol.implicitHeight + 20

                                ColumnLayout {
                                    id: projectOpsCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        UiButton {
                                            Layout.fillWidth: true
                                            text: "添加/切换"
                                            tone: "filled"
                                            onClicked: root.openProjectFolderDialog()
                                        }
                                        UiButton {
                                            Layout.fillWidth: true
                                            text: "重载数据"
                                            tone: "outlined"
                                            onClicked: { appContext.scanPosts(); appContext.loadSiteConfig(); appContext.loadPlugins(); }
                                        }
                                        UiButton {
                                            Layout.fillWidth: true
                                            text: "环境检查"
                                            tone: "outlined"
                                            onClicked: {
                                                root.envStatus = appContext.environmentCheck();
                                                root.envStatusVisible = true;
                                                if (root.envStatus.node && root.envStatus.hexo && root.envStatus.git) {
                                                    envStatusTimer.restart();
                                                } else {
                                                    envStatusTimer.stop();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                visible: root.envStatusVisible
                                Layout.fillWidth: true
                                spacing: 8

                                Item { Layout.fillWidth: true }
                                StatusTag { label: "Node"; ok: !!root.envStatus.node }
                                StatusTag { label: "Hexo"; ok: !!root.envStatus.hexo }
                                StatusTag { label: "Git"; ok: !!root.envStatus.git }
                                Item { Layout.fillWidth: true }
                            }

                            UiCard {
                                Layout.fillWidth: true
                                implicitHeight: Math.max(120, projectListView.contentHeight + 16)
                                color: root.md3SurfaceContainer

                                ListView {
                                    id: projectListView
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    clip: true
                                    model: appContext.projects
                                    reuseItems: true
                                    cacheBuffer: 320
                                    boundsBehavior: Flickable.StopAtBounds
                                    spacing: 6
                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                        minimumSize: 0.08
                                        interactive: true
                                        hoverEnabled: true
                                        width: 6
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: parent.pressed
                                                ? Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, 0.8)
                                                : (parent.hovered
                                                    ? Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, 0.65)
                                                    : Qt.rgba(root.md3Outline.r, root.md3Outline.g, root.md3Outline.b, 0.52))
                                        }
                                        background: Rectangle {
                                            color: "transparent"
                                        }
                                    }
                                    delegate: Rectangle {
                                        width: ListView.view.width
                                        height: 56
                                        radius: root.shapeSmall
                                        color: modelData.path === appContext.currentProjectPath ? root.md3PrimaryContainer : root.md3SurfaceContainerLow
                                        border.color: root.md3OutlineVariant
                                        border.width: 0
                                        property bool isCurrent: modelData.path === appContext.currentProjectPath
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 8
                                            Column {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: modelData.name
                                                    font.weight: Font.Medium
                                                    color: isCurrent ? root.md3OnPrimaryContainer : root.md3OnSurface
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                                Text {
                                                    text: modelData.path
                                                    color: root.md3OnSurfaceVariant
                                                    font.pixelSize: 12
                                                    elide: Text.ElideMiddle
                                                    width: parent.width
                                                }
                                            }
                                            RowLayout {
                                                visible: !isCurrent
                                                spacing: 6
                                                UiButton {
                                                    text: "删除"
                                                    tone: "text"
                                                    danger: true
                                                    onClicked: root.requestDeleteProject(modelData.name, modelData.path)
                                                }
                                                UiButton {
                                                    text: "选择"
                                                    tone: "outlined"
                                                    onClicked: appContext.switchProject(modelData.path)
                                                }
                                            }
                                            UiButton {
                                                visible: isCurrent
                                                enabled: false
                                                text: "已选中"
                                                tone: "tonal"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiCard {
                        visible: root.settingsTabIndex === 2
                        Layout.fillWidth: true
                        implicitHeight: aiConfigCol.implicitHeight + 32
                        color: root.md3SurfaceContainer

                        ColumnLayout {
                            id: aiConfigCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 12

                            Text { text: "AI 配置"; font.pixelSize: 16; font.weight: Font.DemiBold; color: root.md3OnSurface }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: "Provider"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; Layout.preferredWidth: 64 }
                                UiComboBox {
                                    id: aiProviderCombo
                                    Layout.fillWidth: true
                                    model: ["none", "deepseek", "glm", "openai"]
                                    currentIndex: model.indexOf(appContext.aiProvider) >= 0 ? model.indexOf(appContext.aiProvider) : 0
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: "API Base"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; Layout.preferredWidth: 64 }
                                UiTextField {
                                    id: aiApiBaseInput
                                    Layout.fillWidth: true
                                    text: appContext.aiApiBase
                                    placeholderText: "https://api.deepseek.com"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: "API Key"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; Layout.preferredWidth: 64 }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    UiTextField {
                                        id: aiApiKeyInput
                                        Layout.fillWidth: true
                                        text: {
                                            var k = appContext.aiApiKey
                                            if (k.length <= 4) return k
                                            return k.substring(0, 2) + "****" + k.substring(k.length - 2)
                                        }
                                        placeholderText: "sk-..."
                                        readOnly: !root.aiKeyEditing
                                        echoMode: root.aiKeyEditing ? TextInput.Normal : TextInput.Password
                                    }

                                    UiButton {
                                        text: root.aiKeyEditing ? "保存" : "编辑"
                                        tone: "outlined"
                                        compact: true
                                        onClicked: {
                                            if (root.aiKeyEditing) {
                                                var raw = aiApiKeyInput.text
                                                if (raw.indexOf("****") >= 0) {
                                                    // user didn't change the masked text, keep original
                                                } else {
                                                    appContext.aiApiKey = raw
                                                }
                                                root.aiKeyEditing = false
                                            } else {
                                                aiApiKeyInput.text = appContext.aiApiKey
                                                root.aiKeyEditing = true
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: "Model"; color: root.md3OnSurfaceVariant; font.pixelSize: 13; Layout.preferredWidth: 64 }
                                UiTextField {
                                    id: aiModelInput
                                    Layout.fillWidth: true
                                    text: appContext.aiModel
                                    placeholderText: "deepseek-v4-flash"
                                }
                            }

                            UiButton {
                                Layout.fillWidth: true
                                text: "保存 AI 配置"
                                tone: "filled"
                                onClicked: {
                                    var provider = aiProviderCombo.currentValue || aiProviderCombo.model[aiProviderCombo.currentIndex]
                                    var apiBase = aiApiBaseInput.text.trim()
                                    var model = aiModelInput.text.trim()

                                    // Auto-detect provider from apiBase/model if user left provider as "none"
                                    if (provider === "none") {
                                        var baseLower = apiBase.toLowerCase()
                                        var modelLower = model.toLowerCase()
                                        if (baseLower.indexOf("deepseek") >= 0 || modelLower.indexOf("deepseek") >= 0) {
                                            provider = "deepseek"
                                        } else if (baseLower.indexOf("bigmodel") >= 0 || baseLower.indexOf("zhipu") >= 0 || modelLower.indexOf("glm") >= 0) {
                                            provider = "glm"
                                        } else if (baseLower.indexOf("openai") >= 0 || modelLower.indexOf("gpt") >= 0) {
                                            provider = "openai"
                                        }
                                    }

                                    appContext.aiProvider = provider
                                    appContext.aiApiBase = apiBase
                                    appContext.aiModel = model
                                    if (root.aiKeyEditing) {
                                        var raw = aiApiKeyInput.text
                                        if (raw.indexOf("****") < 0) {
                                            appContext.aiApiKey = raw
                                        }
                                        root.aiKeyEditing = false
                                    }
                                }
                            }
                        }
                    }

                    // ==================== 备份管理 Card ====================
                    UiCard {
                        visible: root.settingsTabIndex === 2
                        Layout.fillWidth: true
                        implicitHeight: backupCol.implicitHeight + 32

                        Connections {
                            target: appContext
                            function onTaskRunningChanged() {
                                if (!appContext.taskRunning && root.settingsTabIndex === 2)
                                    root.backupHistory = appContext.gitLogSync(20)
                            }
                        }

                        ColumnLayout {
                            id: backupCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 12

                            // Header row
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "备份管理"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    color: root.md3OnSurface
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    readonly property bool ok: appContext.isGitRepo()
                                    width: repoLabel.implicitWidth + 16
                                    height: 22
                                    radius: 11
                                    color: ok ? "#E8F5E9" : "#FFF3E0"
                                    Text {
                                        id: repoLabel
                                        anchors.centerIn: parent
                                        text: parent.ok ? "Git 仓库 ✓" : "未初始化"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: parent.ok ? "#2E7D32" : "#E65100"
                                    }
                                }
                            }

                            // Init button shown only when not a git repo
                            UiButton {
                                visible: !appContext.isGitRepo()
                                text: "初始化 Git 仓库"
                                tone: "filled"
                                Layout.fillWidth: true
                                onClicked: {
                                    appContext.gitInit()
                                    root.consoleVisible = true
                                }
                            }

                            // Remote URL row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                UiTextField {
                                    id: remoteUrlInput
                                    Layout.fillWidth: true
                                    placeholderText: "远端地址（https://github.com/user/blog.git）"
                                    Component.onCompleted: text = appContext.gitGetRemote()
                                }
                                UiButton {
                                    text: "设置"
                                    compact: true
                                    implicitWidth: 56
                                    onClicked: appContext.gitSetRemote(remoteUrlInput.text)
                                }
                            }

                            // Backup + Push row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                UiButton {
                                    text: "立即备份"
                                    tone: "filled"
                                    Layout.fillWidth: true
                                    onClicked: {
                                        appContext.backupNow("")
                                        root.consoleVisible = true
                                    }
                                }
                                UiButton {
                                    text: "推送到远端"
                                    Layout.fillWidth: true
                                    onClicked: {
                                        appContext.gitPush()
                                        root.consoleVisible = true
                                    }
                                }
                            }

                            // History section header
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                Text {
                                    text: "备份记录"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: root.md3OnSurface
                                }
                                Item { Layout.fillWidth: true }
                                IconActionButton {
                                    width: 24; height: 24
                                    iconSource: root.iconBase + "play.svg"
                                    toolTipText: "刷新记录"
                                    onClicked: root.backupHistory = appContext.gitLogSync(20)
                                }
                            }

                            // Empty state
                            Text {
                                visible: root.backupHistory.length === 0
                                text: "暂无备份记录"
                                color: root.md3OnSurfaceVariant
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 4
                                Layout.bottomMargin: 4
                            }

                            // History list
                            Repeater {
                                model: root.backupHistory
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: 54
                                    radius: root.shapeMedium
                                    color: index % 2 === 0
                                        ? root.md3SurfaceContainerLowest
                                        : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 6
                                        spacing: 8

                                        Rectangle {
                                            width: 56; height: 22; radius: 6
                                            color: root.md3SurfaceContainerHigh
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.hash
                                                font.family: "Consolas, Courier New"
                                                font.pixelSize: 11
                                                color: root.md3Primary
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: modelData.message
                                                font.pixelSize: 13
                                                color: root.md3OnSurface
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                            Text {
                                                text: modelData.date
                                                font.pixelSize: 11
                                                color: root.md3OnSurfaceVariant
                                            }
                                        }

                                        UiButton {
                                            text: "恢复"
                                            tone: "outlined"
                                            compact: true
                                            onClicked: {
                                                root.showConfirmDialog(
                                                    "恢复文章",
                                                    "将 source/_posts/ 中的文章恢复到 " + modelData.hash
                                                        + " 版本？\n\n当前未提交的修改将丢失，请先备份。",
                                                    "恢复",
                                                    true,
                                                    function() {
                                                        appContext.gitRestorePosts(modelData.fullHash)
                                                        root.consoleVisible = true
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiCard {
                        visible: root.settingsTabIndex === 3
                        Layout.fillWidth: true
                        implicitHeight: statsCol.implicitHeight + 40

                        ColumnLayout {
                            id: statsCol
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12

                            Text {
                                text: "信息统计"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: root.md3OnSurface
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    radius: root.shapeMedium
                                    color: root.md3SurfaceContainerHigh
                                    border.width: 0
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "分类数"; font.pixelSize: 12; color: root.md3OnSurfaceVariant; horizontalAlignment: Text.AlignHCenter; width: 90 }
                                        Text { text: String(root.topicStats.categoryCount || 0); font.pixelSize: 22; font.weight: Font.DemiBold; color: root.md3Primary; horizontalAlignment: Text.AlignHCenter; width: 90 }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    radius: root.shapeMedium
                                    color: root.md3SurfaceContainerHigh
                                    border.width: 0
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "标签数"; font.pixelSize: 12; color: root.md3OnSurfaceVariant; horizontalAlignment: Text.AlignHCenter; width: 90 }
                                        Text { text: String(root.topicStats.tagCount || 0); font.pixelSize: 22; font.weight: Font.DemiBold; color: root.md3Primary; horizontalAlignment: Text.AlignHCenter; width: 90 }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    radius: root.shapeMedium
                                    color: root.md3SurfaceContainerHigh
                                    border.width: 0
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "更新频率"; font.pixelSize: 12; color: root.md3OnSurfaceVariant; horizontalAlignment: Text.AlignHCenter; width: 90 }
                                        Text {
                                            text: root.topicStats.updateFrequency || "样本不足"
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                            color: root.md3Primary
                                            horizontalAlignment: Text.AlignHCenter
                                            width: 120
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 220
                                radius: root.shapeMedium
                                color: root.md3SurfaceContainerLow
                                border.width: 1
                                border.color: root.md3OutlineVariant

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        text: "分类柱状图"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: root.md3OnSurface
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 8

                                        Repeater {
                                            model: root.topicStats.categoryTop || []
                                            delegate: ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 1
                                                Layout.minimumWidth: 0
                                                Layout.fillHeight: true
                                                spacing: 4

                                                Item {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true

                                                    Rectangle {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.bottom: parent.bottom
                                                        width: Math.min(28, parent.width * 0.72)
                                                        height: {
                                                            var top = root.topicStats.categoryTop || [];
                                                            if (!top.length)
                                                                return 0;
                                                            var maxVal = Number(top[0].value || 1);
                                                            return Math.max(6, parent.height * (Number(modelData.value || 0) / Math.max(1, maxVal)));
                                                        }
                                                        radius: 6
                                                        color: modelData.color || root.md3Primary
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    font.pixelSize: 11
                                                    color: root.md3OnSurfaceVariant
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: String(modelData.value)
                                                    font.pixelSize: 11
                                                    color: root.md3OnSurface
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 300
                                radius: root.shapeMedium
                                color: root.md3SurfaceContainerLow
                                border.width: 1
                                border.color: root.md3OutlineVariant

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        text: "标签扇形图"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: root.md3OnSurface
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 12

                                        Canvas {
                                            id: tagPieCanvas
                                            Layout.preferredWidth: 220
                                            Layout.fillHeight: true
                                            antialiasing: true

                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.reset();

                                                var data = root.topicStats.tagTop || [];
                                                if (data.length === 0)
                                                    return;

                                                var total = 0;
                                                for (var i = 0; i < data.length; i++)
                                                    total += Number(data[i].value || 0);
                                                if (total <= 0)
                                                    return;

                                                var cx = width / 2;
                                                var cy = height / 2;
                                                var radius = Math.min(width, height) * 0.40;
                                                var innerRadius = radius * 0.53;
                                                var start = -Math.PI / 2;

                                                for (var j = 0; j < data.length; j++) {
                                                    var item = data[j];
                                                    var ratio = Number(item.value || 0) / total;
                                                    var span = ratio * Math.PI * 2;
                                                    var end = start + span;

                                                    ctx.beginPath();
                                                    ctx.moveTo(cx, cy);
                                                    ctx.arc(cx, cy, radius, start, end, false);
                                                    ctx.closePath();
                                                    ctx.fillStyle = item.color || root.md3Primary;
                                                    ctx.fill();

                                                    start = end;
                                                }

                                                ctx.beginPath();
                                                ctx.arc(cx, cy, innerRadius, 0, Math.PI * 2, false);
                                                ctx.closePath();
                                                ctx.fillStyle = root.md3SurfaceContainerLow;
                                                ctx.fill();
                                            }

                                            Connections {
                                                target: root
                                                function onTopicStatsChanged() { tagPieCanvas.requestPaint(); }
                                            }

                                            Component.onCompleted: requestPaint()
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 8

                                            Repeater {
                                                model: root.topicStats.tagTop || []
                                                delegate: RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Rectangle {
                                                        width: 10
                                                        height: 10
                                                        radius: 5
                                                        color: modelData.color || root.md3Primary
                                                    }
                                                    Text {
                                                        text: modelData.name
                                                        color: root.md3OnSurface
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                    Text {
                                                        text: String(modelData.value)
                                                        color: root.md3OnSurfaceVariant
                                                        font.pixelSize: 12
                                                    }
                                                }
                                            }

                                            Item { Layout.fillHeight: true }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 260
                                radius: root.shapeMedium
                                color: root.md3SurfaceContainerLow
                                border.width: 1
                                border.color: root.md3OutlineVariant

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        text: "更新频率折线图（近 6 个月）"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: root.md3OnSurface
                                    }

                                    Canvas {
                                        id: updateTrendCanvas
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        antialiasing: true

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();

                                            var trend = root.topicStats.trend || [];
                                            if (trend.length === 0)
                                                return;

                                            var w = width;
                                            var h = height;
                                            var padL = 30;
                                            var padR = 16;
                                            var padT = 16;
                                            var padB = 34;
                                            var chartW = Math.max(1, w - padL - padR);
                                            var chartH = Math.max(1, h - padT - padB);
                                            var maxVal = Math.max(1, Number(root.topicStats.trendMax || 1));

                                            ctx.strokeStyle = root.md3OutlineVariant;
                                            ctx.lineWidth = 1;
                                            ctx.beginPath();
                                            ctx.moveTo(padL, padT + chartH);
                                            ctx.lineTo(padL + chartW, padT + chartH);
                                            ctx.stroke();

                                            ctx.strokeStyle = "#5B8FF9";
                                            ctx.lineWidth = 2.5;
                                            ctx.beginPath();
                                            for (var i = 0; i < trend.length; i++) {
                                                var x = padL + (chartW * i / Math.max(1, trend.length - 1));
                                                var y = padT + chartH - chartH * (Number(trend[i].value || 0) / maxVal);
                                                if (i === 0)
                                                    ctx.moveTo(x, y);
                                                else
                                                    ctx.lineTo(x, y);
                                            }
                                            ctx.stroke();

                                            for (var j = 0; j < trend.length; j++) {
                                                var px = padL + (chartW * j / Math.max(1, trend.length - 1));
                                                var py = padT + chartH - chartH * (Number(trend[j].value || 0) / maxVal);

                                                ctx.beginPath();
                                                ctx.fillStyle = "#FFFFFF";
                                                ctx.arc(px, py, 3.5, 0, Math.PI * 2, false);
                                                ctx.fill();

                                                ctx.beginPath();
                                                ctx.strokeStyle = "#5B8FF9";
                                                ctx.lineWidth = 2;
                                                ctx.arc(px, py, 3.5, 0, Math.PI * 2, false);
                                                ctx.stroke();

                                                ctx.fillStyle = root.md3OnSurfaceVariant;
                                                ctx.font = "11px 'Microsoft YaHei UI'";
                                                ctx.textAlign = "center";
                                                ctx.fillText(trend[j].label, px, padT + chartH + 18);
                                            }
                                        }

                                        Connections {
                                            target: root
                                            function onTopicStatsChanged() { updateTrendCanvas.requestPaint(); }
                                        }

                                        Component.onCompleted: requestPaint()
                                    }
                                }
                            }
                        }
                    }

                    // ==================== Site Config Card ====================
                    UiCard {
                        visible: root.settingsTabIndex === 1
                        Layout.fillWidth: true
                        implicitHeight: siteConfigCol.implicitHeight + 40

                        ColumnLayout {
                            id: siteConfigCol
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12

                            Text {
                                text: "站点配置"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: root.md3OnSurface
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                UiButton {
                                    Layout.fillWidth: true
                                    text: "读取站点配置"
                                    tone: "outlined"
                                    onClicked: appContext.loadSiteConfig()
                                }
                            }

                            // Config list
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(480, configModel.count * 56 + 20)
                                Layout.minimumHeight: 120
                                radius: root.shapeMedium
                                color: root.md3SurfaceContainer
                                border.width: 1
                                border.color: root.md3OutlineVariant

                                ListView {
                                    id: cfgList
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    model: configModel
                                    reuseItems: true
                                    cacheBuffer: 480
                                    boundsBehavior: Flickable.StopAtBounds
                                    flickDeceleration: 10000
                                    spacing: 8
                                    delegate: Rectangle {
                                        width: ListView.view.width
                                        height: 48
                                        radius: root.shapeSmall
                                        color: root.md3SurfaceContainerLow
                                        border.width: 0

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Text {
                                                Layout.preferredWidth: 156
                                                text: displayKey
                                                color: root.md3OnSurfaceVariant
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                            }

                                            UiTextField {
                                                id: valueField
                                                text: value
                                                Layout.fillWidth: true
                                                readOnly: false
                                                onTextChanged: configModel.setProperty(index, "value", text)
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                visible: root.settingsTabIndex === 1
                                Layout.fillWidth: true
                                spacing: 8
                                UiButton {
                                    Layout.fillWidth: true
                                    text: "保存到站点"
                                    tone: "filled"
                                    enabled: true
                                    onClicked: {
                                        var out = {};
                                        for (var i = 0; i < configModel.count; i++) out[configModel.get(i).rawKey] = configModel.get(i).value;
                                        root.showConfirmDialog(
                                            "保存站点配置",
                                            "确定要保存站点配置吗？这将直接修改 _config.yml 文件。",
                                            "保存",
                                            false,
                                            function() {
                                                appContext.saveSiteConfig(out);
                                                appContext.loadSiteConfig();
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }

                    UiCard {
                        visible: root.settingsTabIndex === 4
                        Layout.fillWidth: true
                        implicitHeight: trashCol.implicitHeight + 40

                        ColumnLayout {
                            id: trashCol
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "回收站"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    color: root.md3OnSurface
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: trashCountText.implicitWidth + 16
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: root.md3PrimaryContainer
                                    visible: appContext.trashItems.length > 0

                                    Text {
                                        id: trashCountText
                                        anchors.centerIn: parent
                                        text: String(appContext.trashItems.length)
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: root.md3OnPrimaryContainer
                                    }
                                }

                                UiButton {
                                    text: "清空"
                                    tone: "text"
                                    danger: true
                                    compact: true
                                    visible: appContext.trashItems.length > 0
                                    onClicked: {
                                        root.showConfirmDialog(
                                            "清空回收站",
                                            "确定要清空回收站吗？共 " + appContext.trashItems.length + " 篇文章将被永久删除，此操作不可恢复。",
                                            "清空",
                                            true,
                                            function() { appContext.emptyTrash() }
                                        )
                                    }
                                }
                            }

                            Text {
                                visible: appContext.trashItems.length === 0
                                text: "回收站为空"
                                font.pixelSize: 13
                                color: root.md3OnSurfaceVariant
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                Layout.topMargin: 20
                                Layout.bottomMargin: 20
                            }

                            UiCard {
                                visible: appContext.trashItems.length > 0
                                Layout.fillWidth: true
                                color: root.md3SurfaceContainer
                                implicitHeight: Math.max(120, trashListView.contentHeight + 16)

                                ListView {
                                    id: trashListView
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    clip: true
                                    model: appContext.trashItems
                                    reuseItems: true
                                    cacheBuffer: 320
                                    boundsBehavior: Flickable.StopAtBounds
                                    spacing: 6
                                    ScrollBar.vertical: ListScrollBar {}

                                    delegate: Rectangle {
                                        width: ListView.view.width
                                        height: 96
                                        radius: root.shapeSmall
                                        color: root.md3SurfaceContainerLow
                                        border.width: 0

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 6

                                            Text {
                                                text: modelData.title || "未知标题"
                                                font.weight: Font.Medium
                                                color: root.md3OnSurface
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            Item {
                                                width: parent.width
                                                height: Math.max(pathText.implicitHeight, trashBtns.implicitHeight)

                                                Text {
                                                    id: pathText
                                                    anchors.left: parent.left
                                                    anchors.right: trashBtns.left
                                                    anchors.rightMargin: 12
                                                    anchors.bottom: parent.bottom
                                                    text: (modelData.originalPath || "")
                                                    color: root.md3OnSurfaceVariant
                                                    font.pixelSize: 11
                                                    elide: Text.ElideMiddle
                                                }

                                                RowLayout {
                                                    id: trashBtns
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    spacing: 6
                                                    UiButton {
                                                        text: "还原"
                                                        tone: "outlined"
                                                        compact: true
                                                        onClicked: appContext.restorePost(modelData.id)
                                                    }
                                                    UiButton {
                                                        text: "删除"
                                                        tone: "text"
                                                        danger: true
                                                        compact: true
                                                        onClicked: {
                                                            var trashId = modelData.id
                                                            var trashTitle = modelData.title || ""
                                                            root.showConfirmDialog(
                                                                "永久删除",
                                                                "确定要永久删除「" + trashTitle + "」吗？此操作不可恢复。",
                                                                "删除",
                                                                true,
                                                                function() { appContext.permanentlyDeletePost(trashId) }
                                                            )
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                text: "删除于 " + (modelData.deletedAt || "") + " · " + (modelData.daysLeft !== undefined ? modelData.daysLeft : 30) + " 天后过期"
                                                color: root.md3OnSurfaceVariant
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bottom spacer
                    Item {
                        visible: root.settingsTabIndex !== 1
                        Layout.preferredHeight: 40
                    }
                }
            }
        }
    }

    // ======================== Plugin Management Drawer ========================
    Drawer {
        id: pluginDrawer
        edge: Qt.RightEdge
        y: titleBar.height
        width: 400
        height: root.height - titleBar.height

        Rectangle {
            anchors.fill: parent
            color: root.md3Surface

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: pluginPanelContent.implicitHeight + 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 10000
                ScrollBar.vertical: PageScrollBar {}

                ColumnLayout {
                    id: pluginPanelContent
                    width: parent.width - 48
                    x: 24
                    y: 24
                    height: implicitHeight
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        IconImage {
                            width: 20
                            height: 20
                            source: root.iconBase + "plug.svg"
                            color: root.md3Primary
                        }

                        Text {
                            text: "插件管理"
                            font.pixelSize: 22
                            font.weight: Font.Medium
                            color: root.md3OnSurface
                            Layout.fillWidth: true
                        }

                        UiButton {
                            text: "重载"
                            tone: "outlined"
                            compact: true
                            onClicked: appContext.loadPlugins()
                        }

                        IconActionButton {
                            iconSource: root.iconBase + "close.svg"
                            toolTipText: "关闭"
                            onClicked: pluginDrawer.close()
                        }
                    }

                    Text {
                        text: "插件目录：{项目路径}/plugins/*.json"
                        font.pixelSize: 12
                        color: root.md3OnSurfaceVariant
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    UiCard {
                        visible: appContext.plugins.length === 0
                        Layout.fillWidth: true
                        implicitHeight: 88

                        Text {
                            anchors.centerIn: parent
                            text: "当前项目未检测到插件\n请在项目的 plugins/ 目录下放置 .json 插件定义文件"
                            font.pixelSize: 13
                            color: root.md3OnSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            width: parent.width - 32
                        }
                    }

                    UiCard {
                        visible: appContext.plugins.length > 0
                        Layout.fillWidth: true
                        color: root.md3SurfaceContainer
                        implicitHeight: Math.max(80, pluginPanelListView.contentHeight + 16)

                        ListView {
                            id: pluginPanelListView
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            model: appContext.plugins
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 6
                            interactive: false

                            delegate: Rectangle {
                                property var plugin: modelData || ({})
                                width: ListView.view.width
                                height: pluginItemCol.implicitHeight + 24
                                radius: root.shapeSmall
                                color: root.md3SurfaceContainerLow

                                ColumnLayout {
                                    id: pluginItemCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    spacing: 6

                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: 20

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: pluginStateBadge.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: plugin.name || "未命名插件"
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            color: root.md3OnSurface
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            id: pluginStateBadge
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 52
                                            height: 20
                                            radius: 10
                                            color: plugin.state === "loaded"
                                                ? root.md3PrimaryContainer
                                                : root.md3SurfaceContainerHigh

                                            Text {
                                                anchors.centerIn: parent
                                                text: plugin.state === "loaded" ? "已加载" : "未加载"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: plugin.state === "loaded"
                                                    ? root.md3Primary
                                                    : root.md3OnSurfaceVariant
                                            }
                                        }
                                    }

                                    Text {
                                        visible: (plugin.description || "").length > 0
                                        text: plugin.description || ""
                                        font.pixelSize: 12
                                        color: root.md3OnSurfaceVariant
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        UiButton {
                                            text: "运行"
                                            tone: "tonal"
                                            compact: true
                                            enabled: !appContext.taskRunning
                                            onClicked: {
                                                root.pluginLogStart = appContext.logText.length
                                                root.pluginDialogName = plugin.name || "插件"
                                                root.pluginDialogDesc = plugin.description || ""
                                                root.pluginDialogExitCode = -2
                                                root.pluginDialogPending = true
                                                pluginResultDialog.outputText = ""
                                                pluginResultDialog.open()
                                                appContext.runPlugin(plugin.name || "")
                                            }
                                        }

                                        UiButton {
                                            visible: plugin.state === "loaded"
                                            text: "卸载"
                                            tone: "outlined"
                                            compact: true
                                            onClicked: appContext.unloadPlugin(plugin.name || "")
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            visible: (plugin.command || "").length > 0
                                            text: plugin.command || ""
                                            font.pixelSize: 11
                                            font.family: "Consolas, Courier New, monospace"
                                            color: root.md3OnSurfaceVariant
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 160
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SpeedDialFab {
        id: speedDialFab
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 18
        anchors.bottomMargin: 18
        hasOpenedPost: appContext.openedPostPath.length > 0
        settingsDrawerOpen: settingsDrawer.opened
        pluginDrawerOpen: pluginDrawer.opened
        onAddArticleRequested: appContext.newPost("新文章", "未分类", "新标签")
        onAiEditRequested: root.enterAiEditMode()
        onPluginManagementRequested: {
            appContext.loadPlugins()
            pluginDrawer.open()
        }
    }

    // ======================== Plugin Result Dialog ========================
    Dialog {
        id: pluginResultDialog
        property string outputText: ""
        modal: true
        anchors.centerIn: Overlay.overlay
        standardButtons: Dialog.NoButton
        padding: 0
        implicitWidth: 560

        onClosed: root.pluginDialogPending = false

        background: Rectangle {
            radius: root.shapeLarge
            color: root.md3SurfaceContainerLowest
            border.width: 1
            border.color: root.md3OutlineVariant
        }

        contentItem: Item {
            implicitWidth: 560
            implicitHeight: pluginResultCol.implicitHeight + 40

            ColumnLayout {
                id: pluginResultCol
                width: parent.implicitWidth - 40
                anchors.centerIn: parent
                spacing: 16

                // Section 1: 插件信息
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: root.pluginDialogName
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: root.md3OnSurface
                    }
                    Text {
                        visible: root.pluginDialogDesc.length > 0
                        text: root.pluginDialogDesc
                        font.pixelSize: 13
                        color: root.md3OnSurfaceVariant
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.md3OutlineVariant; opacity: 0.5 }

                // Section 2: 过程信息
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: "过程信息"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: root.md3OnSurfaceVariant
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 240
                        radius: root.shapeSmall
                        color: root.md3SurfaceContainer
                        clip: true

                        Flickable {
                            id: pluginOutputFlickable
                            anchors.fill: parent
                            anchors.margins: 12
                            contentWidth: width
                            contentHeight: pluginOutputText.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: PageScrollBar {}
                            onContentHeightChanged: {
                                if (root.pluginDialogPending)
                                    contentY = Math.max(0, contentHeight - height)
                            }

                            Text {
                                id: pluginOutputText
                                width: parent.width
                                text: pluginResultDialog.outputText
                                font.pixelSize: 12
                                font.family: "Consolas, Courier New, monospace"
                                color: root.md3OnSurface
                                wrapMode: Text.WrapAnywhere
                                textFormat: Text.PlainText
                                lineHeight: 1.4
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.md3OutlineVariant; opacity: 0.5 }

                // Section 3: 结果
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "结果"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: root.md3OnSurfaceVariant
                    }
                    Rectangle {
                        implicitWidth: pluginStatusText.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: root.pluginDialogPending
                            ? Qt.rgba(root.md3OnSurfaceVariant.r, root.md3OnSurfaceVariant.g,
                                      root.md3OnSurfaceVariant.b, 0.14)
                            : (root.pluginDialogExitCode === 0
                                ? root.md3PrimaryContainer
                                : root.md3ErrorContainer)
                        Text {
                            id: pluginStatusText
                            anchors.centerIn: parent
                            text: root.pluginDialogPending
                                ? "运行中..."
                                : (root.pluginDialogExitCode === 0
                                    ? "执行成功"
                                    : ("执行失败  exit=" + root.pluginDialogExitCode))
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: root.pluginDialogPending
                                ? root.md3OnSurfaceVariant
                                : (root.pluginDialogExitCode === 0 ? root.md3Primary : root.md3Error)
                        }
                    }
                    Item { Layout.fillWidth: true }
                    UiButton {
                        text: "关闭"
                        tone: "tonal"
                        compact: true
                        onClicked: pluginResultDialog.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: firstRunDialog
        modal: true
        title: "欢迎使用 Visualization for Hexo"
        standardButtons: Dialog.Ok
        anchors.centerIn: Overlay.overlay
        onAccepted: appContext.completeFirstRun()

        contentItem: Column {
            width: 420
            spacing: 10

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: root.md3OnSurface
                text: "首次运行向导：请先配置 Node.js/Hexo/Git，并添加一个 Hexo 项目。"
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: root.md3OnSurfaceVariant
                font.pixelSize: 12
                text: "你可以在设置面板中查看故障诊断信息并一键刷新。"
            }
        }
    }

    Dialog {
        id: initProjectDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        title: ""
        standardButtons: Dialog.NoButton
        padding: 0
        implicitWidth: 460

        function startInit() {
            if (root.initProjectBusy) {
                return
            }
            root.initProjectBusy = true
            root.initProjectStatus = "任务运行中..."
            Qt.callLater(function() {
                var ok = appContext.initializeHexoProject(root.pendingInitProjectPath)
                root.initProjectBusy = false
                root.initProjectStatus = ""
                if (ok) {
                    root.envStatus = appContext.environmentCheck();
                    root.envStatusVisible = true;
                    if (root.envStatus.node && root.envStatus.hexo && root.envStatus.git) {
                        envStatusTimer.restart();
                    } else {
                        envStatusTimer.stop();
                    }
                }
                initProjectDialog.close()
            })
        }

        background: Rectangle {
            radius: root.shapeLarge
            color: root.md3SurfaceContainerLowest
            border.width: 1
            border.color: root.md3OutlineVariant
        }

        contentItem: Item {
            implicitWidth: 460
            implicitHeight: dialogCol.implicitHeight + 40

            ColumnLayout {
                id: dialogCol
                width: parent.implicitWidth - 40
                anchors.centerIn: parent
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: root.md3PrimaryContainer

                        Text {
                            anchors.centerIn: parent
                            text: "!"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: root.md3Primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "初始化 Hexo 项目"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: root.md3OnSurface
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "检测到该目录不是 Hexo 项目，是否执行初始化并切换？"
                            color: root.md3OnSurface
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            width: parent.width
                        }
                        Text {
                            text: "初始化成功后会自动启动预览，并打开浏览器。"
                            color: root.md3OnSurface
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            width: parent.width
                        }
                    }
                }

                UiCard {
                    Layout.fillWidth: true
                    color: root.md3SurfaceContainer
                    implicitHeight: initProjectDetailCol.implicitHeight + 24

                    ColumnLayout {
                        id: initProjectDetailCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Text {
                            text: "目录"
                            color: root.md3OnSurfaceVariant
                            font.pixelSize: 12
                        }
                        Text {
                            text: root.pendingInitProjectPath
                            color: root.md3OnSurface
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                        }
                    }
                }

                UiCard {
                    visible: root.initProjectBusy
                    Layout.fillWidth: true
                    color: root.md3SurfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        BusyIndicator {
                            running: root.initProjectBusy
                            width: 22
                            height: 22
                        }
                        Text {
                            text: root.initProjectStatus
                            color: root.md3OnSurface
                            font.pixelSize: 13
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }
                    UiButton {
                        text: "取消"
                        tone: "outlined"
                        enabled: !root.initProjectBusy
                        onClicked: initProjectDialog.close()
                    }
                    UiButton {
                        text: root.initProjectBusy ? "初始化中..." : "初始化并切换"
                        tone: "filled"
                        enabled: !root.initProjectBusy
                        onClicked: initProjectDialog.startInit()
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteProjectDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        title: ""
        standardButtons: Dialog.NoButton
        padding: 0
        implicitWidth: 420

        background: Rectangle {
            radius: root.shapeLarge
            color: root.md3SurfaceContainerLowest
            border.width: 1
            border.color: root.md3OutlineVariant
        }

        contentItem: Item {
            implicitWidth: 420
            implicitHeight: deleteDialogCol.implicitHeight + 40

            ColumnLayout {
                id: deleteDialogCol
                width: parent.implicitWidth - 40
                anchors.centerIn: parent
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: root.md3ErrorContainer

                        Text {
                            anchors.centerIn: parent
                            text: "!"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: root.md3Error
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "删除项目"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: root.md3OnSurface
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "该操作仅移除本地项目记录，不会删除磁盘文件。"
                            color: root.md3OnSurface
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            width: parent.width
                        }
                    }
                }

                UiCard {
                    Layout.fillWidth: true
                    color: root.md3SurfaceContainer
                    implicitHeight: deleteProjectDetailCol.implicitHeight + 24

                    ColumnLayout {
                        id: deleteProjectDetailCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Text {
                            text: "项目"
                            color: root.md3OnSurfaceVariant
                            font.pixelSize: 12
                        }
                        Text {
                            text: root.pendingDeleteProjectName
                            color: root.md3OnSurface
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            width: parent.width
                        }
                        Text {
                            text: root.pendingDeleteProjectPath
                            color: root.md3OnSurfaceVariant
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                            width: parent.width
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }
                    UiButton {
                        text: "取消"
                        tone: "outlined"
                        onClicked: deleteProjectDialog.close()
                    }
                    UiButton {
                        text: "删除"
                        tone: "filled"
                        danger: true
                        onClicked: {
                            appContext.removeProject(root.pendingDeleteProjectPath)
                            root.pendingDeleteProjectPath = ""
                            root.pendingDeleteProjectName = ""
                            deleteProjectDialog.close()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: confirmDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        title: ""
        standardButtons: Dialog.NoButton
        padding: 0
        implicitWidth: 420

        background: Rectangle {
            radius: root.shapeLarge
            color: root.md3SurfaceContainerLowest
            border.width: 1
            border.color: root.md3OutlineVariant
        }

        contentItem: Item {
            implicitWidth: 420
            implicitHeight: confirmDialogCol.implicitHeight + 40

            ColumnLayout {
                id: confirmDialogCol
                width: parent.implicitWidth - 40
                anchors.centerIn: parent
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: root.confirmDialogIsDanger ? root.md3ErrorContainer : root.md3PrimaryContainer

                        Text {
                            anchors.centerIn: parent
                            text: "?"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: root.confirmDialogIsDanger ? root.md3Error : root.md3Primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root.confirmDialogTitle
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: root.md3OnSurface
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.confirmDialogMessage
                            color: root.md3OnSurface
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            width: parent.width
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }
                    UiButton {
                        text: "取消"
                        tone: "outlined"
                        onClicked: {
                            root.pendingConfirmCallback = null
                            confirmDialog.close()
                        }
                    }
                    UiButton {
                        text: root.confirmDialogConfirmText
                        tone: "filled"
                        danger: root.confirmDialogIsDanger
                        onClicked: {
                            if (root.pendingConfirmCallback) {
                                root.pendingConfirmCallback()
                                root.pendingConfirmCallback = null
                            }
                            confirmDialog.close()
                        }
                    }
                }
            }
        }
    }

    FolderDialog {
        id: projectFolderDialog
        title: "选择 Hexo 项目目录"
        onAccepted: {
            var pickedUrl = selectedFolder
            if (!pickedUrl || pickedUrl.toString().length === 0) {
                pickedUrl = currentFolder
            }
            var selected = root.toLocalPath(pickedUrl)
            if (!selected || selected.length === 0) {
                appContext.appendStructuredLog("warn", "PROJECT", "folder dialog accepted but empty")
                return
            }
            appContext.appendStructuredLog("info", "PROJECT", "selected folder: " + selected)
            root.addOrInitializeProject(selected)
        }
    }

    FileDialog {
        id: coverFileDialog
        title: "选择封面图片"
        nameFilters: ["图片文件 (*.png *.jpg *.jpeg *.webp *.gif *.bmp)"]
        onAccepted: {
            var selected = selectedFile ? selectedFile.toString() : ""
            if (!selected || selected.length === 0) {
                return
            }
            var imported = appContext.importCoverToCurrentProject(selected)
            if (imported && imported.length > 0) {
                coverInput.text = imported
            }
        }
    }
}
