import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Body drawing only. The surrounding Help/PanelFrame owns input and commands.
Item {
    id: root
    objectName: "operatorHelpForm"
    implicitWidth: 1044
    implicitHeight: 562
    width: implicitWidth
    height: implicitHeight
    property alias searchControl: search
    property alias resetAllControl: resetAllButton
    property alias undoControl: undoButton
    property alias saveControl: saveButton
    property alias actionViewControl: actions
    property alias guideViewControl: guide
    property int tabCount: 0
    property int entryCount: 0
    property int guideCount: 0
    property Component tabDelegate: null
    property Component actionDelegate: null
    property Component guideDelegate: null
    property bool showGuide: false
    property string queryText: ""
    property string statusText: "快捷键首选项未接通"
    property string feedbackText: "Designer绘制参考 · 没有保存、录入或启用快捷键。"
    property string emptyText: "没有已提供的快捷键条目"
    property bool statusWarning: false
    property bool recording: false
    property bool resetAllEnabled: false
    property bool undoEnabled: false
    property bool saveEnabled: false
    property real tabSpacing: 10
    property real sectionSpacing: 12
    property real contentFooterGap: 8
    property real rowSpacing: 6
    property real actionContentInset: 16
    property real scrollBarWidth: 8
    property real guideSpacing: 12
    property real controlHeight: 36
    property real statusWidth: 272
    property real searchGap: 14
    property real searchBreakpoint: 680
    property real tabBreakpoint: 650
    property real feedbackHeight: 40
    property real emptyMinimumHeight: 32
    property real footerBottomInset: 6
    property real footerSpacing: 14
    property real footerGap: 12
    property real footerBreakpoint: 680
    property real resetWidth: 170
    property real undoWidth: 170
    property real saveWidth: 172
    property real noteSize: 12
    property real inputSize: 14
    property real actionNoteSize: 11
    property real actionTitleSize: 14
    property real actionBindingSize: 14
    property real guideTitleSize: 14
    property real guideKeySize: 14
    property color surfaceColor: Theme.hudSolid
    property color rowSurfaceColor: Theme.hudSurface
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color recordingColor: Theme.green
    property color rowBorderColor: Theme.hudBorder
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property color inputBorderColor: Theme.line
    property string fontFamily: Theme.fontFamily
    property string numberFamily: Theme.numberFamily
    readonly property int tabColumns: Math.min(Math.max(1, root.tabCount), root.width >= root.tabBreakpoint ? 4 : 2)
    readonly property real tabDelegateWidth: Math.max(0, (tabs.width - root.tabSpacing * (root.tabColumns - 1)) / root.tabColumns)
    readonly property real actionDelegateWidth: Math.max(0, actions.width - root.actionContentInset)
    readonly property real guideDelegateWidth: guideColumn.width
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: header
        width: root.width
        spacing: root.sectionSpacing
        Grid { id: tabs; width: parent.width; columns: root.tabColumns; spacing: root.tabSpacing; Repeater { model: root.tabCount; delegate: root.tabDelegate } }
        GridLayout {
            width: parent.width
            columns: root.width >= root.searchBreakpoint ? 2 : 1
            columnSpacing: root.searchGap
            rowSpacing: root.sectionSpacing
            OperatorInput {
                id: search
                objectName: "shortcutSearch"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: root.controlHeight
                visible: !root.showGuide
                label: "搜索快捷键"
                placeholderText: "搜索功能、按键或面板"
                text: root.queryText
                color: root.textColor
                backgroundColor: root.inputSurfaceColor
                borderColor: root.inputBorderColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            }
            OperatorText {
                Layout.fillWidth: root.width < root.searchBreakpoint || root.showGuide
                Layout.preferredWidth: root.width >= root.searchBreakpoint && !root.showGuide ? root.statusWidth : 0
                Layout.minimumWidth: 0
                Layout.preferredHeight: Math.max(root.controlHeight, implicitHeight)
                text: root.statusText
                size: root.noteSize
                color: root.statusWarning ? root.warningColor : root.mutedColor
                font.family: root.fontFamily
                horizontalAlignment: root.width >= root.searchBreakpoint ? Text.AlignRight : Text.AlignLeft
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
    }
    ListView {
        id: actions
        objectName: "shortcutActionList"
        y: header.height + root.sectionSpacing
        width: root.width
        height: Math.max(0, feedback.y - root.contentFooterGap - y)
        clip: true
        spacing: root.rowSpacing
        model: root.entryCount
        delegate: root.actionDelegate
        visible: !root.showGuide
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            id: actionScrollBar
            objectName: "shortcutActionScrollBar"
            width: root.scrollBarWidth
            minimumSize: 0.08
            policy: actions.contentHeight > actions.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            background: Rectangle { color: root.inputSurfaceColor; radius: 3 }
            contentItem: Rectangle {
                implicitWidth: 6; implicitHeight: 40; radius: 3
                color: actionScrollBar.pressed ? root.textColor : root.mutedColor
                opacity: actionScrollBar.active ? 0.9 : 0.6
            }
        }
        OperatorText { anchors.centerIn: parent; width: parent.width; height: Math.max(root.emptyMinimumHeight, implicitHeight); text: root.emptyText; horizontalAlignment: Text.AlignHCenter; visible: root.entryCount === 0; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
    OperatorScrollableColumn {
        id: guide
        y: actions.y
        width: root.width
        height: actions.height
        visible: root.showGuide
        Column { id: guideColumn; width: parent.width; spacing: root.guideSpacing; Repeater { model: root.guideCount; delegate: root.guideDelegate } }
    }
    OperatorText {
        id: feedback
        y: footer.y - root.footerSpacing - height
        width: root.width
        height: Math.max(root.feedbackHeight, implicitHeight)
        text: root.feedbackText
        size: root.noteSize
        color: root.recording ? root.recordingColor : root.mutedColor
        font.family: root.fontFamily
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    GridLayout {
        id: footer
        width: root.width
        y: root.height - height - root.footerBottomInset
        height: implicitHeight
        columns: root.width >= root.footerBreakpoint ? 4 : 2
        columnSpacing: root.footerGap
        rowSpacing: root.sectionSpacing
        OperatorButton { id: resetAllButton; Layout.preferredWidth: root.resetWidth; Layout.fillWidth: root.width < root.footerBreakpoint; Layout.minimumWidth: 0; Layout.preferredHeight: root.controlHeight; text: "恢复全部默认"; enabled: root.resetAllEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
        OperatorButton { id: undoButton; Layout.preferredWidth: root.undoWidth; Layout.fillWidth: root.width < root.footerBreakpoint; Layout.minimumWidth: 0; Layout.preferredHeight: root.controlHeight; text: "撤销未保存修改"; enabled: root.undoEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
        Item { visible: root.width >= root.footerBreakpoint; Layout.fillWidth: true; Layout.preferredWidth: 0; height: root.controlHeight }
        OperatorButton { id: saveButton; objectName: "saveShortcutBindings"; Layout.preferredWidth: root.saveWidth; Layout.fillWidth: root.width < root.footerBreakpoint; Layout.columnSpan: root.width < root.footerBreakpoint ? 2 : 1; Layout.minimumWidth: 0; Layout.preferredHeight: root.controlHeight; text: "保存快捷键"; primary: true; enabled: root.saveEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
    }
}
