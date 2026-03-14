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
    x: Screen.width / 2 - width / 2
    y: Screen.height / 2 - height / 2
    minimumWidth: 1100
    minimumHeight: 700
    title: "Visualization for Hexo"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: layoutBg

    Rectangle {
        anchors.fill: parent
        color: root.layoutBg
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
    property int settingsTabIndex: 0
    property int articleViewMode: 1 // 0: source, 1: preview
    property bool splitDragDegrade: false
    property bool resizeDegrade: false
    property bool suppressResizeDegrade: false
    readonly property bool degradeRendering: resizeDegrade || splitDragDegrade
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
    property string liveMarkdownText: ""
    property string previewCoverSource: ""
    property var envStatus: ({ node: false, hexo: false, git: false, project: false })
    property bool envStatusVisible: false
    property string pendingInitProjectPath: ""
    property real normalWindowX: x
    property real normalWindowY: y
    property real normalWindowWidth: width
    property real normalWindowHeight: height
    readonly property int edgeSnapThreshold: 18
    readonly property string iconBase: "qrc:/qt/qml/visualization for hexo/assets/iconpark/"
    readonly property bool isWindowMaximized: root.visibility === Window.Maximized || ((root.windowState & Qt.WindowMaximized) !== 0)
    readonly property bool isWindowFullScreen: root.visibility === Window.FullScreen || ((root.windowState & Qt.WindowFullScreen) !== 0)

    onConsoleVisibleChanged: {
        if (consoleVisible && consoleRect) {
            consoleRect.expanded = true
        }
        Qt.callLater(function() {
            if (centerContentSplit) {
                centerContentSplit.forceLayout()
            }
        })
        Qt.callLater(function() {
            if (centerContentSplit) {
                centerContentSplit.forceLayout()
            }
        })
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

    onWidthChanged: {
        if (!root.visible || root.suppressResizeDegrade) return;
        resizeDegrade = true
        resizeSettleTimer.restart()
    }

    onHeightChanged: {
        if (!root.visible || root.suppressResizeDegrade) return;
        resizeDegrade = true
        resizeSettleTimer.restart()
    }

    onResizeDegradeChanged: {
            // Keep hook for future adaptive tuning.
    }

    onSplitDragDegradeChanged: {
            // Keep hook for future adaptive tuning.
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
        windowStateRefreshTimer.restart()
    }

    onWindowStateChanged: {
        if (!root.visible) {
            return
        }
        windowStateRefreshTimer.restart()
    }

    function forceMainLayoutSync() {
        if (mainContentSplit) {
            mainContentSplit.forceLayout()
        }
        if (centerContentSplit) {
            centerContentSplit.forceLayout()
        }
        if (editorScrollView) {
            editorScrollView.returnToBounds()
        }
        if (editorContent && editorContent.isMarkdown) {
            previewRenderTimer.restart()
        }
    }

    function editorBodyHeight() {
        if (root.degradeRendering) {
            return 320
        }

        var previewHeight = mdPreview.implicitHeight
        if (coverPreview.visible) {
            previewHeight += coverPreview.height + 10
        }

        var contentHeight = editorContent.isMarkdown ? previewHeight : bodyEdit.contentHeight
        return Math.max(contentHeight, 240)
    }

    function rememberNormalWindowGeometry() {
        if (root.isWindowMaximized) return;
        normalWindowX = root.x;
        normalWindowY = root.y;
        normalWindowWidth = root.width;
        normalWindowHeight = root.height;
    }

    function showWindowMaximizedSafe() {
        root.rememberNormalWindowGeometry()
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
        if (root.isWindowMaximized) {
            root.showNormal()
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
        var nextPreview = appContext.renderMarkdownForPreview(nextText, root.uiBodyFontSize, root.uiLineSpacing);
        if (root.liveMarkdownText !== nextPreview) {
            root.liveMarkdownText = nextPreview;
        }
    }

    function toggleConsoleExpanded() {
        if (!consoleRect) {
            return;
        }
        if (!root.consoleVisible) {
            return;
        }
        consoleRect.expanded = !consoleRect.expanded;
    }

    function toggleConsoleVisibility() {
        root.consoleVisible = !root.consoleVisible;
        if (root.consoleVisible) {
            consoleRect.expanded = true;
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
                        return uiBtn.hovered ? Qt.rgba(root.md3Error.r, root.md3Error.g, root.md3Error.b, 0.12) : "transparent";
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
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }

        contentItem: Loader {
            sourceComponent: cb.editable ? editableComboContent : readonlyComboContent
        }

        Component {
            id: editableComboContent
            TextInput {
                id: editableInput
                leftPadding: 0
                rightPadding: 0
                text: cb.editText
                font: cb.font
                color: root.md3OnSurface
                verticalAlignment: Text.AlignVCenter
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
                text: cb.displayText
                font: cb.font
                color: root.md3OnSurface
                verticalAlignment: Text.AlignVCenter
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

    onSettingsTabIndexChanged: root.refreshConfigRows()

    Connections {
        target: appContext
        onConfigMapChanged: root.refreshConfigRows()
        onPostsChanged: root.refreshTopicStats()
        function onCurrentProjectPathChanged() {
            root.refreshTopicStats()
        }
    }

    Component.onCompleted: {
        root.refreshConfigRows();
        root.liveMarkdownText = "";
        root.envStatus = appContext.environmentCheck();
        root.diagnosticsText = JSON.stringify(appContext.diagnosticsReport(), null, 2)
        root.refreshTopicStats();
        titleInput.text = appContext.openedPostTitle
        categoryInput.editText = appContext.openedPostCategory
        tagsInput.editText = appContext.openedPostTags
        dateInput.editText = appContext.openedPostDate
        bodyEdit.text = appContext.openedPostBody
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
        onTriggered: root.resizeDegrade = false
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
                        root.consoleVisible = true
                        appContext.appendStructuredLog("info", "DEPLOY_CLICK", "requested: hexo deploy")
                        if (!appContext.currentProjectPath || appContext.currentProjectPath.length === 0) {
                            appContext.appendStructuredLog("warn", "DEPLOY_NO_PROJECT", "请先选择 Hexo 项目后再发布")
                            return
                        }
                        var env = appContext.environmentCheck()
                        if (!env.hexo || !env.git) {
                            appContext.appendStructuredLog("warn", "DEPLOY_ENV", "发布依赖 hexo 和 git，请检查环境")
                        }
                        appContext.runHexoDeploy()
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
                
                IconActionButton {
                    width: root.topBarButtonSize
                    height: root.topBarButtonSize
                    iconSource: root.iconBase + "MeteorIconsSidebar.svg"
                    toolTipText: "开关左侧文章列表"
                    onClicked: {
                        sidebar.visible = !sidebar.visible
                        sidebar.SplitView.preferredWidth = sidebar.visible ? root.fixedSidebarWidth : 0
                    }
                }

                IconActionButton {
                    width: root.topBarButtonSize
                    height: root.topBarButtonSize
                    iconSource: root.iconBase + "TablerLayoutBottombar.svg"
                    toolTipText: "开关底栏"
                    onClicked: root.toggleConsoleVisibility()
                }
            }
        }

        Rectangle {
            id: centeredModeToggle
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 148
            height: 30
            radius: 15
            color: root.md3SurfaceContainerHigh
            border.width: 1
            border.color: root.md3OutlineVariant
            z: 14

            Row {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 2

                Rectangle {
                    width: 71
                    height: 26
                    radius: 13
                    color: !editorContent.isMarkdown ? root.md3SecondaryContainer : "transparent"
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        text: "源码"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: !editorContent.isMarkdown ? root.md3OnSecondaryContainer : root.md3OnSurfaceVariant
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.articleViewMode = 0
                    }
                }

                Rectangle {
                    width: 71
                    height: 26
                    radius: 13
                    color: editorContent.isMarkdown ? root.md3SecondaryContainer : "transparent"
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        text: "预览"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: editorContent.isMarkdown ? root.md3OnSecondaryContainer : root.md3OnSurfaceVariant
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.articleViewMode = 1
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

            ColumnLayout {
                anchors.fill: parent
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
                        }
                    }
                }

                // Posts list
                ListView {
                    id: postsList
                    property real quantizedWidth: Math.max(320, Math.round(width / 20) * 20)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: appContext.posts
                    reuseItems: true
                    cacheBuffer: 360
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 13000
                    maximumFlickVelocity: 6400

                    delegate: Item {
                        property var postEntry: modelData || ({})
                        width: ListView.view.width
                        height: 86

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

                            MouseArea {
                                id: postMouse
                                anchors.fill: parent
                                hoverEnabled: !root.resizeDegrade
                                onClicked: {
                                    if (postEntry.path) {
                                        appContext.openPost(postEntry.path)
                                    }
                                }
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPressAndHold: {
                                    if (postEntry.path) {
                                        appContext.deletePost(postEntry.path)
                                    }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: 14

                                Text {
                                    id: postTitle
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: deleteBtn.visible ? deleteBtn.left : parent.right
                                    anchors.rightMargin: deleteBtn.visible ? 8 : 0
                                    text: postEntry.title || ""
                                    font.pixelSize: 15
                                    font.weight: postEntry.path === appContext.openedPostPath ? Font.DemiBold : Font.Normal
                                    color: root.md3OnSurface
                                    elide: Text.ElideRight
                                }

                                UiButton {
                                    id: deleteBtn
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: -4
                                    text: "删除"
                                    tone: "text"
                                    danger: true
                                    compact: true
                                    visible: !!postEntry.path && (postMouse.containsMouse || (postEntry.path === appContext.openedPostPath))
                                    onClicked: appContext.deletePost(postEntry.path)
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
        }

        // ==================== Center Area (Editor + Console) ====================
        SplitView {
            id: centerContentSplit
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            orientation: Qt.Vertical

            handle: Item {
                id: centerSplitHandle
                visible: root.consoleVisible
                implicitHeight: root.consoleVisible ? 16 : 0
                // Make the drag handle obvious and easy to grab.
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, SplitHandle.pressed ? 0.16 : 0.08)
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(parent.width - 20, 180)
                    height: SplitHandle.pressed ? 6 : (SplitHandle.hovered ? 5 : 4)
                    radius: 2
                    color: SplitHandle.pressed ? root.md3Primary
                         : (SplitHandle.hovered ? root.md3Primary : root.md3OutlineVariant)
                    opacity: SplitHandle.hovered || SplitHandle.pressed ? 1.0 : 0.82
                }
                // Cursor hint
                HoverHandler { cursorShape: Qt.SplitVCursor }
                SplitHandle.onPressedChanged: {
                    if (!root.consoleVisible) {
                        return
                    }
                    root.splitDragDegrade = SplitHandle.pressed
                }
            }

            // ---- Editor Area ----
            Rectangle {
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                color: root.layoutBg

                Item {
                    id: editorViewport
                    anchors.fill: parent
                    clip: true

                    Flickable {
                        id: editorScrollView
                        anchors.fill: parent
                        clip: true
                        interactive: !root.degradeRendering
                        contentWidth: width
                        contentHeight: editorContent.implicitHeight + 24
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 12000
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                        Column {
                            id: editorContent
                            property bool isMarkdown: true
                            property real computedWidth: Math.max(400, Math.min(980, editorScrollView.width - 72))
                            property real quantizedWidth: Math.max(400, Math.min(980, Math.round(computedWidth / 24) * 24))
                            width: root.resizeDegrade ? quantizedWidth : computedWidth
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
                                        indicator: Item {
                                            width: 0
                                            height: 0
                                        }
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
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

                        // Editor body
                        StackLayout {
                            visible: !root.degradeRendering
                            width: parent.width
                            height: root.editorBodyHeight()
                            currentIndex: editorContent.isMarkdown ? 1 : 0

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
                                    if (editorContent.isMarkdown && !root.degradeRendering) {
                                        previewRenderTimer.restart()
                                    }
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

                                Text {
                                    id: mdPreview
                                    width: parent.width
                                    text: root.liveMarkdownText
                                    textFormat: Text.RichText
                                    wrapMode: Text.WordWrap
                                    renderType: Text.NativeRendering
                                    font.pixelSize: root.uiBodyFontSize
                                    font.family: "SimSun"
                                    lineHeight: root.uiLineSpacing
                                    lineHeightMode: Text.ProportionalHeight
                                    color: root.readingInk
                                    onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                                }
                            }
                        }

                        Rectangle {
                            visible: root.degradeRendering
                            width: parent.width
                            height: Math.max(320, editorScrollView.height - (editorContent.y + y + 28))
                            radius: root.shapeLarge
                            color: Qt.rgba(root.md3OnSurface.r, root.md3OnSurface.g, root.md3OnSurface.b, 0.03)
                            border.width: 1
                            border.color: root.md3OutlineVariant

                            Text {
                                anchors.centerIn: parent
                                text: "正在调整大小"
                                font.pixelSize: 14
                                color: root.md3OnSurfaceVariant
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
                    if (!root.degradeRendering) {
                        root.syncPreviewText(true)
                    }
                }
            }

            Connections {
                target: appContext
                function onOpenedPostChanged() {
                    titleInput.text = appContext.openedPostTitle
                    categoryInput.editText = appContext.openedPostCategory
                    tagsInput.editText = appContext.openedPostTags
                    dateInput.editText = appContext.openedPostDate
                    coverInput.text = appContext.openedPostCover
                    descriptionInput.text = appContext.openedPostDescription
                    bodyEdit.text = appContext.openedPostBody
                    if (editorContent.isMarkdown) {
                        previewRenderTimer.restart()
                    } else {
                        root.liveMarkdownText = ""
                    }
                    Qt.callLater(function() {
                        editorScrollView.contentY = 0
                    })
                }
            }

            // ---- Console ----
            Rectangle {
                id: consoleRect
                visible: root.consoleVisible
                SplitView.fillWidth: true
                SplitView.preferredHeight: root.consoleVisible ? (expanded ? 200 : root.consoleCollapsedHeight) : 0
                SplitView.minimumHeight: root.consoleVisible ? root.consoleCollapsedHeight : 0
                color: root.md3InverseSurface

                property bool expanded: false
                onHeightChanged: {
                    if (height <= root.consoleCollapsedHeight + 2 && expanded) {
                        expanded = false;
                    } else if (height > root.consoleCollapsedHeight + 20 && !expanded) {
                        expanded = true;
                    }
                }

                Rectangle {
                    id: consoleHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 36
                    color: Qt.darker(root.md3InverseSurface, 1.15)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 8

                        Text {
                            text: "控制台"
                            color: root.md3InverseOnSurface
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            opacity: 0.85
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 6

                            Text {
                                text: consoleRect.expanded ? "收起" : "展开"
                                color: root.md3InverseOnSurface
                                font.pixelSize: 12
                                opacity: 0.6
                            }

                            IconImage {
                                width: 12
                                height: 12
                                source: consoleRect.expanded
                                    ? "qrc:/qt/qml/visualization for hexo/assets/iconpark/down.svg"
                                    : "qrc:/qt/qml/visualization for hexo/assets/iconpark/up.svg"
                                color: Qt.rgba(root.md3InverseOnSurface.r, root.md3InverseOnSurface.g, root.md3InverseOnSurface.b, 0.72)
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleConsoleExpanded()
                    }
                }

                ScrollView {
                    id: logScroll
                    anchors.top: consoleHeader.bottom
                    anchors.bottom: consoleInputRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12
                    clip: true
                    visible: consoleRect.height > 40
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                    TextArea {
                        id: logText
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
                        opacity: 0.85
                        onTextChanged: {
                            Qt.callLater(function() {
                                if (logScroll.contentItem) {
                                    logScroll.contentItem.contentY = Math.max(0, logScroll.contentItem.contentHeight - logScroll.contentItem.height);
                                }
                            });
                        }
                    }
                }

                Rectangle {
                    id: consoleInputRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 42
                    color: Qt.rgba(root.md3InverseOnSurface.r, root.md3InverseOnSurface.g, root.md3InverseOnSurface.b, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(root.md3InverseOnSurface.r, root.md3InverseOnSurface.g, root.md3InverseOnSurface.b, 0.16)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        TextField {
                            id: consoleInputField
                            Layout.fillWidth: true
                            placeholderText: "输入命令回车执行；Ctrl+C 或 /ctrl+c 中断当前任务"
                            placeholderTextColor: "#FFFFFF"
                            color: root.md3InverseOnSurface
                            selectionColor: Qt.rgba(root.md3Primary.r, root.md3Primary.g, root.md3Primary.b, 0.45)
                            selectedTextColor: root.md3OnPrimary
                            font.family: "Consolas"
                            font.pixelSize: 12
                            enabled: root.consoleVisible
                            Keys.onPressed: function(event) {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
                                    appContext.submitConsoleInput("/ctrl+c")
                                    event.accepted = true
                                }
                            }
                            background: Rectangle {
                                radius: 6
                                color: Qt.rgba(root.md3InverseOnSurface.r, root.md3InverseOnSurface.g, root.md3InverseOnSurface.b, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(root.md3InverseOnSurface.r, root.md3InverseOnSurface.g, root.md3InverseOnSurface.b, 0.22)
                            }
                            onAccepted: {
                                var cmd = text.trim()
                                if (cmd.length === 0)
                                    return
                                appContext.submitConsoleInput(cmd)
                                text = ""
                            }
                        }
                    }
                }
            }
        }
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
                contentHeight: (root.settingsTabIndex === 1)
                    ? height
                    : settingsContent.implicitHeight + 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 10000
                interactive: root.settingsTabIndex !== 1
                ScrollBar.vertical: ScrollBar {
                    policy: (root.settingsTabIndex === 1)
                        ? ScrollBar.AlwaysOff
                        : ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: settingsContent
                    width: parent.width - 48
                    x: 24
                    y: 24
                    height: (root.settingsTabIndex === 1)
                        ? (settingsViewport.height - 48)
                        : implicitHeight
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
                        height: 82
                        radius: root.shapeLarge
                        color: root.md3SurfaceContainerLow

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: "文章设置", glyph: "文" },
                                    { label: "站点设置", glyph: "站" },
                                    { label: "系统设置", glyph: "系" },
                                    { label: "信息统计", glyph: "统" }
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
                                                : root.md3SurfaceContainerHigh
                                            anchors.horizontalCenter: parent.horizontalCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.glyph
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
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
                                        UiTextField {
                                            id: projPathInput
                                            text: appContext.currentProjectPath || "D:/hexo-blog"
                                            Layout.fillWidth: true
                                        }
                                        UiButton {
                                            text: "添加/切换"
                                                Layout.preferredWidth: 120
                                            tone: "filled"
                                            onClicked: root.addOrInitializeProject(projPathInput.text)
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

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
                                Layout.preferredHeight: 198
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
                                    delegate: Rectangle {
                                        width: ListView.view.width
                                        height: 56
                                        radius: root.shapeSmall
                                        color: modelData.path === appContext.currentProjectPath ? root.md3PrimaryContainer : root.md3SurfaceContainerLow
                                        border.color: root.md3OutlineVariant
                                        border.width: 0
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            Column {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: modelData.name
                                                    font.weight: Font.Medium
                                                    color: modelData.path === appContext.currentProjectPath ? root.md3OnPrimaryContainer : root.md3OnSurface
                                                    elide: Text.ElideRight
                                                    width: projectListView.width - 160
                                                }
                                                Text {
                                                    text: modelData.path
                                                    color: root.md3OnSurfaceVariant
                                                    font.pixelSize: 12
                                                    elide: Text.ElideMiddle
                                                    width: projectListView.width - 160
                                                }
                                            }
                                            UiButton {
                                                text: modelData.path === appContext.currentProjectPath ? "已选中" : "选择"
                                                tone: modelData.path === appContext.currentProjectPath ? "tonal" : "outlined"
                                                onClicked: appContext.switchProject(modelData.path)
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
                        Layout.fillHeight: root.settingsTabIndex === 1
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
                                Layout.fillHeight: true
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
                                        appContext.saveSiteConfig(out);
                                        appContext.loadSiteConfig();
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

    Rectangle {
        id: addFab
        visible: !root.consoleVisible
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 24
        anchors.bottomMargin: 24
        width: 54
        height: 54
        radius: 27
        color: root.md3Primary
        border.width: 1
        border.color: Qt.rgba(root.md3OnPrimary.r, root.md3OnPrimary.g, root.md3OnPrimary.b, 0.24)
        z: 20

        // Subtle drop shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            anchors.topMargin: 2
            z: -1
            radius: 27
            color: Qt.rgba(0, 0, 0, 0.15)
            visible: true
        }

        Text {
            anchors.centerIn: parent
            text: "+"
            color: "#FFFFFF"
            font.pixelSize: 34
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        ToolTip {
            visible: addFabMouse.containsMouse
            text: "新增文章"
            delay: 120
            timeout: 1800

            contentItem: Text {
                text: "新增文章"
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

        MouseArea {
            id: addFabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: appContext.newPost("新文章", "未分类", "新标签")
        }

        Behavior on color { ColorAnimation { duration: 120 } }
        
        Rectangle {
            anchors.fill: parent
            radius: 27
            color: root.md3OnPrimary
            opacity: addFabMouse.pressed ? 0.12 : (addFabMouse.containsMouse ? 0.08 : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
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
        title: "初始化 Hexo 项目"
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: Overlay.overlay
        onAccepted: {
            if (appContext.initializeHexoProject(root.pendingInitProjectPath)) {
                root.envStatus = appContext.environmentCheck();
                root.envStatusVisible = true;
                if (root.envStatus.node && root.envStatus.hexo && root.envStatus.git) {
                    envStatusTimer.restart();
                } else {
                    envStatusTimer.stop();
                }
            }
        }

        contentItem: Column {
            width: 420
            spacing: 10

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: root.md3OnSurface
                text: "检测到该目录不是 Hexo 项目。是否执行初始化（hexo init）并自动切换到该项目？"
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: root.md3OnSurfaceVariant
                text: "目录: " + root.pendingInitProjectPath + "\n初始化成功后会自动启动预览服务。"
                font.pixelSize: 12
            }
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
