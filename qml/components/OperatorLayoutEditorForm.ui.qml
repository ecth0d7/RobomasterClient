import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 面板正文绘制。默认不伪造HUD偏好、原生扩展目录或活动状态。
Item {
    id: root
    objectName: "layoutEditorForm"
    implicitWidth: 584
    implicitHeight: 582
    width: implicitWidth
    height: implicitHeight
    property alias hudTabControl: hudTabButton
    property alias panelsTabControl: panelsTabButton
    property alias hiddenOnlyControl: hiddenOnlyCheck
    property alias restoreControl: restoreButton
    property alias doneControl: doneButton
    property alias listControl: scroll
    property Component entryDelegate: null
    property int entryCount: 0
    readonly property real entryDelegateWidth: componentRows.width
    property bool showingPanels: false
    property bool hudTabEnabled: false
    property bool hiddenOnlyValue: false
    property bool restoreEnabled: false
    property bool feedbackWarning: false
    property bool emptyVisible: true
    property string headingText: "Designer绘制参考 · 布局宿主未接通"
    property string descriptionText: "未读取真实显示偏好或原生扩展目录；此Form不保存或打开面板。"
    property string hudTabText: "HUD · 未接通"
    property string panelsTabText: "面板库 · 未接通"
    property string hiddenOnlyText: "只看已隐藏组件"
    property string feedbackText: "尚未取得原生面板目录。"
    property string emptyText: "没有接通条目，不填造活动组件或扩展。"
    property string footerText: "显示偏好与有效比赛数据分别处理。"
    property real headerGap: 4
    property real headingMinimumHeight: 28
    property real descriptionMinimumHeight: 42
    property real tabsGap: 8
    property real tabSpacing: 12
    property real tabsBreakpoint: 420
    property real controlHeight: 38
    property real filterGap: 6
    property real filterMinimumHeight: 42
    property real filterControlHeight: 32
    property real listGap: 6
    property real listBottomGap: 10
    property real listRightPadding: 16
    property real rowSpacing: 4
    property real footerSpacing: 8
    property real footerNoteMinimumHeight: 28
    property real footerButtonSpacing: 12
    property real emptyInset: 12
    property real emptyTopInset: 18
    property real emptyMinimumHeight: 70
    property real scrollbarWidth: 8
    property real scrollbarMinimumSize: 0.12
    property real scrollbarThumbWidth: 6
    property real scrollbarThumbHeight: 40
    property real scrollbarRadius: 3
    property real scrollbarActiveOpacity: 0.9
    property real scrollbarIdleOpacity: 0.6
    property real headingSize: 16
    property real descriptionSize: 12
    property real noteSize: 11
    property real emptySize: 13
    property real rowTitleSize: 13
    property real rowNoteSize: 11
    property real widgetSize: 12
    property real rowLeftInset: 10
    property real rowRightInset: 10
    property real rowActionWidth: 88
    property real rowActionGap: 18
    property real rowActionHeight: 34
    property real rowPanelMinimumHeight: 62
    property real rowHudMinimumHeight: 48
    property real rowTextSpacing: 2
    property real rowTitleTop: 6
    property real rowBottomInset: 7
    property real rowTitleMinimumHeight: 25
    property real rowDetailMinimumHeight: 22
    property real rowStateWidth: 88
    property real rowBreakpoint: 420
    property real rowToggleTextPadding: 8
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color rowEvenColor: "#26332e"
    property color rowOddColor: "#202b27"
    property color scrollbarTrackColor: "#14201a"
    property color scrollbarThumbColor: Theme.muted
    property color scrollbarPressedColor: Theme.text
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: headerColumn
        width: parent.width
        spacing: root.headerGap
        OperatorText { width: parent.width; height: Math.max(root.headingMinimumHeight, implicitHeight); text: root.headingText; size: root.headingSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: Math.max(root.descriptionMinimumHeight, implicitHeight); text: root.descriptionText; size: root.descriptionSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
    GridLayout {
        id: tabs
        y: headerColumn.implicitHeight + root.tabsGap
        width: parent.width
        columns: width >= root.tabsBreakpoint ? 2 : 1
        columnSpacing: root.tabSpacing
        rowSpacing: root.tabSpacing
        OperatorButton { id: hudTabButton; objectName: "layoutHudTab"; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.preferredHeight: root.controlHeight; text: root.hudTabText; primary: !root.showingPanels; enabled: root.hudTabEnabled; font.family: root.fontFamily; textColor: root.textColor }
        OperatorButton { id: panelsTabButton; objectName: "layoutPanelsTab"; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.preferredHeight: root.controlHeight; text: root.panelsTabText; primary: root.showingPanels; font.family: root.fontFamily; textColor: root.textColor }
    }
    Item {
        id: filterSlot
        y: tabs.y + tabs.implicitHeight + root.filterGap
        width: parent.width
        height: Math.max(root.filterMinimumHeight, root.showingPanels ? feedbackLabel.implicitHeight : root.filterControlHeight)
        OperatorCheckBox { id: hiddenOnlyCheck; x: 2; width: Math.max(0, parent.width - x); height: root.filterControlHeight; visible: !root.showingPanels; text: root.hiddenOnlyText; checked: root.hiddenOnlyValue; font.family: root.fontFamily; textColor: root.textColor }
        OperatorText { id: feedbackLabel; width: parent.width; height: implicitHeight; visible: root.showingPanels; text: root.feedbackText; size: root.noteSize; color: root.feedbackWarning ? root.warningColor : root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
    ScrollView {
        id: scroll
        objectName: "layoutComponentList"
        y: filterSlot.y + filterSlot.height + root.listGap
        width: parent.width
        height: Math.max(0, footer.y - root.listBottomGap - y)
        clip: true
        contentWidth: availableWidth
        contentHeight: componentRows.implicitHeight
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical: ScrollBar {
            id: verticalScroll
            parent: scroll
            x: scroll.width - width
            y: 0
            height: scroll.height
            policy: scroll.contentHeight > scroll.availableHeight ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: root.scrollbarWidth
            minimumSize: root.scrollbarMinimumSize
            background: Rectangle { color: root.scrollbarTrackColor; radius: root.scrollbarRadius }
            contentItem: Rectangle { implicitWidth: root.scrollbarThumbWidth; implicitHeight: root.scrollbarThumbHeight; radius: root.scrollbarRadius; color: verticalScroll.pressed ? root.scrollbarPressedColor : root.scrollbarThumbColor; opacity: verticalScroll.active ? root.scrollbarActiveOpacity : root.scrollbarIdleOpacity }
        }
        Column {
            id: componentRows
            width: Math.max(0, scroll.availableWidth - root.listRightPadding)
            spacing: root.rowSpacing
            Repeater { model: root.entryCount; delegate: root.entryDelegate }
        }
    }
    OperatorText {
        x: root.emptyInset
        y: scroll.y + root.emptyTopInset
        width: Math.max(0, root.width - root.emptyInset * 2)
        height: Math.max(root.emptyMinimumHeight, implicitHeight)
        visible: root.emptyVisible
        text: root.emptyText
        size: root.emptySize
        color: root.mutedColor
        font.family: root.fontFamily
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone
    }
    Column {
        id: footer
        y: root.height - implicitHeight
        width: parent.width
        spacing: root.footerSpacing
        OperatorText { width: parent.width; height: Math.max(root.footerNoteMinimumHeight, implicitHeight); text: root.footerText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        GridLayout {
            width: parent.width
            columns: root.showingPanels || width < root.tabsBreakpoint ? 1 : 2
            columnSpacing: root.footerButtonSpacing
            rowSpacing: root.footerButtonSpacing
            OperatorButton { id: restoreButton; objectName: "layoutRestoreRole"; visible: !root.showingPanels; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.preferredHeight: root.controlHeight; text: "恢复全部组件"; enabled: root.restoreEnabled; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: doneButton; objectName: "layoutDone"; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.preferredHeight: root.controlHeight; text: "完成"; primary: true; font.family: root.fontFamily; textColor: root.textColor }
        }
    }
}
