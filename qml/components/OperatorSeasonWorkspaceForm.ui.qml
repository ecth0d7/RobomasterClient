import QtQuick
import QtQuick.Layouts

// Workspace body only. The surrounding PanelFrame retains close/focus ownership.
Item {
    id: root
    objectName: "seasonWorkspaceForm"
    implicitWidth: 1384
    implicitHeight: 732
    width: implicitWidth
    height: implicitHeight
    property string headerTitleText: "赛季目录未接通"
    property string headerDescriptionText: "Designer绘制参考；未提供正式规则或生产数据。"
    property string profileDisplayText: "明确选择规则版本"
    property string environmentDisplayText: "明确选择部署用途"
    property string scopeHintText: "宿主未接通，不保存或创建服务。"
    property string feedbackText: "宿主未接通，不保存或创建生产能力。"
    property string opportunitiesIntroText: "候选字段名称属于本项目数据规划，不是官方Protobuf字段。规则确认不代表生产源已接通；没有数据的比赛卡片保持隐藏。"
    property string fontFamily: Theme.fontFamily
    property var profileTitles: []
    property var environmentTitles: []
    property bool referenceEnabled: false
    property bool scopeEditable: false
    property bool undoEnabled: false
    property bool saveEnabled: false
    property bool feedbackEmphasized: false
    property int selectedPage: 0
    // null保留Designer直接绘制；生产端提供首次访问集合，切换时不销毁已有控件。
    property var loadedPages: null
    property int profileIndex: -1
    property int environmentIndex: -1
    property int tabCount: 0
    property int opportunityCount: 0
    property int scopeColumns: width >= scopeWideBreakpoint ? 3 : width
                                                              >= scopeCompactBreakpoint ? 2 : 1
    property int tabColumns: Math.min(
                                 Math.max(1, tabCount),
                                 width >= tabsWideBreakpoint ? 12 : width >= tabsMediumBreakpoint ? 6 : width >= tabsCompactBreakpoint ? 4 : 2)
    property real chromeSpacing: 16
    property real pageSpacing: 16
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real sectionTitleSize: 14
    property real contentMargin: 14
    property real bodyTop: 47
    property real tabSpacing: 12
    property real headerMinimumHeight: 84
    property real headerInset: 16
    property real headerVerticalInset: 10
    property real headerActionWidth: 214
    property real headerBreakpoint: 900
    property real profileWidth: 430
    property real environmentWidth: 254
    property real scopeWideBreakpoint: 1100
    property real scopeCompactBreakpoint: 740
    property real tabsWideBreakpoint: 1200
    property real tabsMediumBreakpoint: 900
    property real tabsCompactBreakpoint: 650
    property real controlHeight: 38
    property real headerTitleSize: 16
    property real noteSize: 12
    property real inputSize: 14
    property real footerSize: 11
    property real footerHeight: 50
    property real footerActionSpacing: 12
    property real undoWidth: 156
    property real saveWidth: 186
    property real footerBreakpoint: 850
    property color surfaceColor: Theme.hudSolid
    property color headerSurfaceColor: Theme.hudSurface
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property Component tabDelegate: null
    property Component opportunityDelegate: null
    readonly property real tabDelegateWidth: Math.max(
                                                 0,
                                                 (tabsGrid.width - root.tabSpacing
                                                  * (root.tabColumns - 1)) / root.tabColumns)
    readonly property real pageWidth: page0Host.width
    readonly property real opportunityDelegateWidth: page1Host.width
    property Component page0Delegate: null
    property Component page2Delegate: null
    property Component page3Delegate: null
    property Component page4Delegate: null
    property Component page5Delegate: null
    property Component page6Delegate: null
    property Component page7Delegate: null
    property Component page8Delegate: null
    property Component page9Delegate: null
    property Component page10Delegate: null
    property Component page11Delegate: null
    property alias referenceControl: referenceButton
    property alias profileControl: profileSelect
    property alias environmentControl: environmentSelect
    property alias undoControl: undoButton
    property alias saveControl: saveButton
    property alias contentControl: content
    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        z: -1
    }
    Column {
        id: chromeColumn
        width: root.width
        spacing: root.chromeSpacing
        Rectangle {
            width: parent.width
            height: Math.max(
                        root.headerMinimumHeight,
                        headerGrid.implicitHeight + root.headerVerticalInset * 2)
            color: root.headerSurfaceColor
            OperatorOutline {
                color: root.separatorColor
            }
            GridLayout {
                id: headerGrid
                x: root.headerInset
                y: root.headerVerticalInset
                width: parent.width - root.headerInset * 2
                columns: root.width >= root.headerBreakpoint ? 2 : 1
                columnSpacing: root.chromeSpacing
                rowSpacing: root.chromeSpacing
                Column {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    spacing: 4
                    OperatorText {
                        width: parent.width
                        height: Math.max(28, implicitHeight)
                        text: root.headerTitleText
                        size: root.headerTitleSize
                        color: root.textColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                    OperatorText {
                        width: parent.width
                        height: Math.max(30, implicitHeight)
                        text: root.headerDescriptionText
                        size: root.noteSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
                OperatorButton {
                    id: referenceButton
                    objectName: "seasonReferenceView"
                    Layout.preferredWidth: root.headerActionWidth
                    Layout.fillWidth: root.width < root.headerBreakpoint
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: root.controlHeight
                    text: "查看26版界面"
                    enabled: root.referenceEnabled
                    textColor: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(root.inputSize,
                                             9.5 / Math.max(0.1, hudScale))
                }
            }
        }
        GridLayout {
            width: parent.width
            columns: root.scopeColumns
            columnSpacing: 12
            rowSpacing: root.chromeSpacing
            OperatorSelect {
                id: profileSelect
                objectName: "seasonProfileSelect"
                Layout.preferredWidth: root.scopeColumns === 3 ? root.profileWidth : 0
                Layout.fillWidth: root.scopeColumns < 3
                Layout.minimumWidth: 0
                Layout.preferredHeight: root.controlHeight
                label: "规则赛季与阶段"
                enabled: root.scopeEditable
                model: root.profileTitles
                currentIndex: root.profileIndex
                displayText: root.profileDisplayText
                emptyText: root.profileDisplayText
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize,
                                         9.5 / Math.max(0.1, hudScale))
            }
            OperatorSelect {
                id: environmentSelect
                objectName: "seasonEnvironmentSelect"
                Layout.preferredWidth: root.scopeColumns === 3 ? root.environmentWidth : 0
                Layout.fillWidth: root.scopeColumns < 3
                Layout.minimumWidth: 0
                Layout.preferredHeight: root.controlHeight
                label: "部署用途"
                enabled: root.scopeEditable
                model: root.environmentTitles
                currentIndex: root.environmentIndex
                displayText: root.environmentDisplayText
                emptyText: root.environmentDisplayText
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize,
                                         9.5 / Math.max(0.1, hudScale))
            }
            OperatorText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.columnSpan: root.scopeColumns === 2 ? 2 : 1
                Layout.preferredHeight: Math.max(root.controlHeight,
                                                 implicitHeight)
                text: root.scopeHintText
                size: root.footerSize
                color: root.mutedColor
                font.family: root.fontFamily
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
        Grid {
            id: tabsGrid
            width: parent.width
            columns: root.tabColumns
            spacing: root.tabSpacing
            Repeater {
                model: root.tabCount
                delegate: root.tabDelegate
            }
        }
    }
    OperatorScrollableColumn {
        id: content
        objectName: "seasonWorkspaceContent"
        y: chromeColumn.height + root.chromeSpacing
        width: root.width
        height: Math.max(0, footer.y - root.chromeSpacing - y)

        Column {
            id: page0Host
            objectName: "seasonPage0Host"
            visible: root.selectedPage === 0
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(0) ? 1 : 0
                delegate: root.page0Delegate
            }
        }
        Column {
            id: page1Host
            objectName: "seasonPage1Host"
            visible: root.selectedPage === 1
            width: parent.width
            spacing: root.formSpacing
            OperatorText {
                width: parent.width
                height: implicitHeight
                text: root.opportunitiesIntroText
                size: root.noteSize
                color: root.warningColor
                font.family: root.fontFamily
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(1) ? root.opportunityCount : 0
                delegate: root.opportunityDelegate
            }
        }
        Column {
            id: page2Host
            objectName: "seasonPage2Host"
            visible: root.selectedPage === 2
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(2) ? 1 : 0
                delegate: root.page2Delegate
            }
        }
        Column {
            id: page3Host
            objectName: "seasonPage3Host"
            visible: root.selectedPage === 3
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(3) ? 1 : 0
                delegate: root.page3Delegate
            }
        }
        Column {
            id: page4Host
            objectName: "seasonPage4Host"
            visible: root.selectedPage === 4
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(4) ? 1 : 0
                delegate: root.page4Delegate
            }
        }
        Column {
            id: page5Host
            objectName: "seasonPage5Host"
            visible: root.selectedPage === 5
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(5) ? 1 : 0
                delegate: root.page5Delegate
            }
        }
        Column {
            id: page6Host
            objectName: "seasonPage6Host"
            visible: root.selectedPage === 6
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(6) ? 1 : 0
                delegate: root.page6Delegate
            }
        }
        Column {
            id: page7Host
            objectName: "seasonPage7Host"
            visible: root.selectedPage === 7
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(7) ? 1 : 0
                delegate: root.page7Delegate
            }
        }
        Column {
            id: page8Host
            objectName: "seasonPage8Host"
            visible: root.selectedPage === 8
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(8) ? 1 : 0
                delegate: root.page8Delegate
            }
        }
        Column {
            id: page9Host
            objectName: "seasonPage9Host"
            visible: root.selectedPage === 9
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(9) ? 1 : 0
                delegate: root.page9Delegate
            }
        }
        Column {
            id: page10Host
            objectName: "seasonPage10Host"
            visible: root.selectedPage === 10
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(10) ? 1 : 0
                delegate: root.page10Delegate
            }
        }
        Column {
            id: page11Host
            objectName: "seasonPage11Host"
            visible: root.selectedPage === 11
            width: parent.width
            Repeater {
                model: root.loadedPages===null || root.loadedPages.includes(11) ? 1 : 0
                delegate: root.page11Delegate
            }
        }
    }
    GridLayout {
        id: footer
        x: 0
        y: root.height - height
        width: root.width
        height: root.width >= root.footerBreakpoint ? root.footerHeight : implicitHeight
        columns: root.width >= root.footerBreakpoint ? 2 : 1
        columnSpacing: root.chromeSpacing
        rowSpacing: root.chromeSpacing
        OperatorText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            Layout.preferredHeight: Math.max(root.footerHeight - 2,
                                             implicitHeight)
            text: root.feedbackText
            size: root.footerSize
            color: root.feedbackEmphasized ? root.textColor : root.mutedColor
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Row {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: root.footerActionSpacing
            OperatorButton {
                id: undoButton
                objectName: "seasonUndo"
                width: root.undoWidth
                height: root.controlHeight
                text: "撤销选择"
                enabled: root.undoEnabled
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize,
                                         9.5 / Math.max(0.1, hudScale))
            }
            OperatorButton {
                id: saveButton
                objectName: "seasonSave"
                width: root.saveWidth
                height: root.controlHeight
                text: "保存赛季与用途"
                primary: true
                enabled: root.saveEnabled
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize,
                                         9.5 / Math.max(0.1, hudScale))
            }
        }
    }
}
