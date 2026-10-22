import QtQuick
import QtQuick.Layouts

// 诊断正文只绘制已提供的值；原生服务、草稿与动作留在包装层。
Item {
    id: root
    property bool drawingBackgroundVisible: true
    property color drawingBackgroundColor: Theme.hudSolid
    Rectangle { anchors.fill: parent; visible: root.drawingBackgroundVisible; color: root.drawingBackgroundColor; z: -1 }
    property alias pagesControl: pages
    property alias settingsControl: settingsButton
    property alias linkContainer: links
    property alias extensionContainer: extensions
    property real linkMaximumHeight: 0
    property real extensionMaximumHeight: 0
    property int selectedPage: -1
    property var loadedPages: null
    property int tabCount: 0
    property int overviewCount: 0
    property int linkCount: 0
    property int groupCount: 0
    property int commandCount: 0
    property int extensionCount: 0
    property int pluginCount: 0
    property int controlCount: 0
    property Component tabDelegate: null
    property Component overviewDelegate: null
    property Component linkDelegate: null
    property Component groupDelegate: null
    property Component commandDelegate: null
    property Component extensionDelegate: null
    property Component pluginDelegate: null
    property Component controlDelegate: null
    property Component innovationDelegate: null
    property string footerText: "服务诊断宿主未接通"
    property bool settingsEnabled: false
    property real tabSpacing: 12
    property real tabHeight: 38
    property real tabBreakpoint: 1000
    property real pageGap: 16
    property real pageBottomGap: 20
    property real columnGap: 12
    property real rowGap: 12
    property real overviewBreakpoint: 800
    property real tableBreakpoint: 800
    property real extensionBreakpoint: 1100
    property real sectionBodyTop: 47
    property real sectionContentMargin: 14
    property real sectionTitleSize: 14
    property real emptyHeight: 72
    property real cardMinimumHeight: 184
    property real cardStatusHeight: 52
    property real cardStatusSize: 13
    property real cardRowsTop: 60
    property real cardRowHeight: 24
    property real tableRowHeight: 40
    property real tableDetailMinimumHeight: 74
    property real tableLabelHeight: 30
    property real tableDetailValueTop: 32
    property real tableDetailBottomPadding: 6
    property real tableLabelFraction: 0.42
    property real tableValueLeftFraction: 0.44
    property real labelSize: 11
    property real valueSize: 12
    property real inputSize: 14
    property real groupRowHeight: 50
    property real groupTitleSize: 12
    property real commandMinimumHeight: 92
    property real commandTitleSize: 13
    property real noteSize: 11
    property real footerNoteHeight: 42
    property real footerButtonHeight: 38
    property real footerButtonWidth: 200
    property real footerGap: 20
    property real footerBreakpoint: 600
    property string fontFamily: Theme.fontFamily
    property string numberFamily: Theme.numberFamily
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color successColor: Theme.green
    property color busyColor: Theme.blue
    property color lineColor: Theme.line
    property color surfaceColor: "transparent"
    property color sectionSurfaceColor: "transparent"
    property color sectionBorderColor: Theme.line
    readonly property int tabColumns: Math.min(Math.max(1, root.tabCount), root.width >= 1200 ? 8 : root.width >= 760 ? 4 : 2)
    readonly property real tabDelegateWidth: Math.max(0, (tabs.width - root.tabSpacing * (root.tabColumns - 1)) / root.tabColumns)
    readonly property real pageWidth: pageColumn.width
    readonly property int overviewColumns: root.pageWidth >= root.overviewBreakpoint ? 2 : 1
    readonly property real overviewWidth: Math.max(0, (root.pageWidth - root.columnGap * (root.overviewColumns - 1)) / root.overviewColumns)
    readonly property int linkColumns: root.pageWidth >= root.tableBreakpoint ? 2 : 1
    readonly property real linkWidth: Math.max(0, (root.pageWidth - root.columnGap * (root.linkColumns - 1)) / root.linkColumns)
    readonly property int extensionColumns: root.pageWidth >= root.extensionBreakpoint ? 3 : root.pageWidth >= root.tableBreakpoint ? 2 : 1
    readonly property real extensionWidth: Math.max(0, (root.pageWidth - root.columnGap * (root.extensionColumns - 1)) / root.extensionColumns)
    readonly property real groupDelegateWidth: groupList.width
    readonly property real commandDelegateWidth: commandList.width
    implicitWidth: 1304
    implicitHeight: 692
    width: root.implicitWidth
    height: root.implicitHeight
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Grid {
        id: tabs
        width: root.width; columns: root.tabColumns; spacing: root.tabSpacing
        Repeater { model: root.tabCount; delegate: root.tabDelegate }
    }
    OperatorScrollableColumn {
        id: pages
        y: tabs.height + root.pageGap
        width: root.width
        height: Math.max(0, footer.y - root.pageBottomGap - y)
        entrySpacing: 0
        Column {
            id: pageColumn
            width: parent.width
            Grid {
                width: parent.width
                objectName: "servicesPage0Host"
                visible: root.selectedPage === 0
                columns: root.overviewColumns; columnSpacing: root.columnGap; rowSpacing: root.rowGap
                Repeater { model: root.loadedPages===null || root.loadedPages.includes(0) ? root.overviewCount : 0; delegate: root.overviewDelegate }
            }
            Flow {
                id: links
                width: parent.width
                objectName: "servicesPage1Host"
                visible: root.selectedPage === 1
                spacing: root.columnGap
                Repeater { model: root.loadedPages===null || root.loadedPages.includes(1) ? root.linkCount : 0; delegate: root.linkDelegate }
            }
            Flow {
                id: dataColumns
                width: parent.width
                objectName: "servicesPage2Host"
                visible: root.selectedPage === 2
                spacing: root.columnGap
                property real cellWidth: root.linkWidth
                OperatorSection {
                    width: dataColumns.cellWidth
                    height: groupList.implicitHeight + bodyTop + contentMargin
                    title: "遥测分组与字段时效"
                    bodyTop: root.sectionBodyTop; contentMargin: root.sectionContentMargin; titleSize: root.sectionTitleSize
                    fontFamily: root.fontFamily; titleColor: root.textColor; outlineColor: root.sectionBorderColor; surfaceColor: root.sectionSurfaceColor
                    Column {
                        id: groupList
                        width: parent.width
                        OperatorText { width: parent.width; height: root.emptyHeight; visible: root.groupCount === 0; text: "尚未提供遥测时效"; color: root.mutedColor; size: root.valueSize; font.family: root.fontFamily }
                        Repeater { model: root.loadedPages===null || root.loadedPages.includes(2) ? root.groupCount : 0; delegate: root.groupDelegate }
                    }
                }
                OperatorSection {
                    width: dataColumns.cellWidth
                    height: commandList.implicitHeight + bodyTop + contentMargin
                    title: "本地操作记录"
                    bodyTop: root.sectionBodyTop; contentMargin: root.sectionContentMargin; titleSize: root.sectionTitleSize
                    fontFamily: root.fontFamily; titleColor: root.textColor; outlineColor: root.sectionBorderColor; surfaceColor: root.sectionSurfaceColor
                    Column {
                        id: commandList
                        width: parent.width
                        OperatorText { width: parent.width; height: root.emptyHeight; visible: root.commandCount === 0; text: "尚无操作记录"; color: root.mutedColor; size: root.valueSize; font.family: root.fontFamily }
                        Repeater { model: root.loadedPages===null || root.loadedPages.includes(2) ? root.commandCount : 0; delegate: root.commandDelegate }
                    }
                }
            }
            Flow {
                id: extensions
                width: parent.width
                objectName: "servicesPage3Host"
                visible: root.selectedPage === 3
                spacing: root.columnGap
                Repeater { model: root.loadedPages===null || root.loadedPages.includes(3) ? root.extensionCount : 0; delegate: root.extensionDelegate }
            }
            Column {
                width: parent.width
                objectName: "servicesPage4Host"
                visible: root.selectedPage === 4
                spacing: root.rowGap
                Repeater { model: root.loadedPages===null || root.loadedPages.includes(4) ? root.pluginCount : 0; delegate: root.pluginDelegate }
            }
            Column {
                width: parent.width
                objectName: "servicesPage5Host"
                visible: root.selectedPage === 5
                Repeater { model: root.loadedPages===null || root.loadedPages.includes(5) ? root.controlCount : 0; delegate: root.controlDelegate }
            }
            Loader {
                objectName:"servicesPage7Host"
                width:parent.width
                active:root.loadedPages===null || root.loadedPages.includes(7)
                sourceComponent:root.innovationDelegate
                visible:root.selectedPage===7
            }
            OperatorText {
                width: parent.width; height: Math.max(root.emptyHeight, implicitHeight)
                visible: root.selectedPage < 0
                text: "未接通诊断目录；没有自动启动、连接或操作记录。"
                size: root.valueSize; color: root.mutedColor; font.family: root.fontFamily
                wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
        }
    }
    GridLayout {
        id: footer
        width: root.width
        y: root.height - height
        height: implicitHeight
        columns: root.width >= root.footerBreakpoint ? 2 : 1
        columnSpacing: root.footerGap; rowSpacing: root.rowGap
        OperatorText {
            Layout.fillWidth: true; Layout.minimumWidth: 0
            Layout.preferredWidth: 0; Layout.preferredHeight: Math.max(root.footerNoteHeight, implicitHeight)
            text: root.footerText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily
            wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        OperatorButton {
            id: settingsButton
            Layout.preferredWidth: root.footerButtonWidth
            Layout.fillWidth: root.width < root.footerBreakpoint
            Layout.preferredHeight: root.footerButtonHeight
            text: "返回设置"; enabled: root.settingsEnabled; textColor: root.textColor
            font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
    }
}
