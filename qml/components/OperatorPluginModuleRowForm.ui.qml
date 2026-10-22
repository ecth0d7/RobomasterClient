import QtQuick
import QtQuick.Layouts

// 当前进程中一个原生模块的绘制；没有插件发现、选择或启停调用。
Item {
    id: root
    objectName: "pluginModuleRowForm"
    property alias selectControl: selectButton
    property alias enableControl: enableButton
    property alias helpControl: helpButton
    property string usageText: ""
    property bool usageExpanded: false
    property string roleText: "Designer绘制参考 · 模块未接通"
    property string identityText: "没有原生插件ID"
    property string classificationText: "未提供核心／可选角色状态。"
    property string nameText: "未提供名称"
    property string statusText: "未接通原生目录；不能推断运行或连接状态。"
    property string selectText: "选择此插件"
    property string enableText: "启用服务"
    property string footerText: "仅明确操作才提交意图"
    property bool warning: false
    property bool selectEnabled: false
    property bool enableEnabled: false
    property bool enablePrimary: false
    property real minimumHeight: 144
    property real contentMargin: 14
    property real topInset: 10
    property real bottomInset: 10
    property real columnGap: 34
    property real rowGap: 12
    property real breakpoint: 900
    property real identityWidth: 228
    property real identitySpacing: 4
    property real identityHintGap: 10
    property real roleMinimumHeight: 28
    property real identityMinimumHeight: 26
    property real classificationMinimumHeight: 44
    property real statusSpacing: 6
    property real nameMinimumHeight: 28
    property real statusMinimumHeight: 70
    property real actionWidth: 182
    property real controlHeight: 36
    property real actionTop: 8
    property real actionSpacing: 12
    property real actionNoteGap: 8
    property real actionNoteMinimumHeight: 24
    property real separatorInset: 14
    property real separatorWidth: 1
    property real roleSize: 15
    property real identitySize: 12
    property real classificationSize: 11
    property real nameSize: 13
    property real noteSize: 12
    property real actionNoteSize: 10
    property real actionSize: 14
    property color surfaceColor: Theme.hudSurface
    property color outlineColor: Theme.hudBorder
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily
    property string identityFontFamily: Theme.numberFamily
    implicitWidth: 1200
    implicitHeight: Math.max(root.minimumHeight, moduleGrid.implicitHeight + root.topInset + root.bottomInset)
    width: implicitWidth
    height: implicitHeight

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorOutline { color: root.warning ? root.warningColor : root.outlineColor }
    Rectangle { x: root.contentMargin + root.identityWidth + root.columnGap / 2; y: root.separatorInset; width: root.separatorWidth; height: Math.max(0, root.height - root.separatorInset * 2); visible: moduleGrid.columns > 1; color: root.separatorColor }
    GridLayout {
        id: moduleGrid
        x: root.contentMargin
        y: root.topInset
        width: Math.max(0, root.width - root.contentMargin * 2)
        columns: root.width >= root.breakpoint ? 3 : 1
        columnSpacing: root.columnGap
        rowSpacing: root.rowGap
        Item {
            Layout.fillWidth: moduleGrid.columns === 1
            Layout.minimumWidth: 0
            Layout.preferredWidth: moduleGrid.columns > 1 ? root.identityWidth : -1
            Layout.alignment: Qt.AlignTop
            implicitHeight: identityColumn.implicitHeight + root.identityHintGap + classificationLabel.height
            Column {
                id: identityColumn
                width: parent.width
                spacing: root.identitySpacing
                OperatorText { width: parent.width; height: Math.max(root.roleMinimumHeight, implicitHeight); text: root.roleText; size: root.roleSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: Math.max(root.identityMinimumHeight, implicitHeight); text: root.identityText; size: root.identitySize; color: root.textColor; font.family: root.identityFontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            }
            OperatorText { id: classificationLabel; y: identityColumn.implicitHeight + root.identityHintGap; width: parent.width; height: Math.max(root.classificationMinimumHeight, implicitHeight); text: root.classificationText; size: root.classificationSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        }
        Column {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: root.statusSpacing
            OperatorText { width: parent.width; height: Math.max(root.nameMinimumHeight, implicitHeight); text: root.nameText; size: root.nameSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: Math.max(root.statusMinimumHeight, implicitHeight); text: root.statusText; size: root.noteSize; color: root.warning ? root.warningColor : root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        }
        Column {
            Layout.fillWidth: moduleGrid.columns === 1
            Layout.minimumWidth: 0
            Layout.preferredWidth: moduleGrid.columns > 1 ? root.actionWidth : -1
            Layout.alignment: Qt.AlignTop
            topPadding: root.actionTop
            spacing: root.actionSpacing
            OperatorButton { id: selectButton; objectName: "pluginModuleSelect"; width: parent.width; height: root.controlHeight; text: root.selectText; enabled: root.selectEnabled; font.family: root.fontFamily; font.pixelSize: Math.max(root.actionSize, 9.5 / Math.max(0.1, hudScale)); textColor: root.textColor }
            OperatorButton { id: helpButton; objectName: "pluginModuleHelp"; width: parent.width; height: root.controlHeight; text: root.usageExpanded ? "收起使用说明" : "如何启动 / 使用"; enabled: root.usageText.length > 0 }
            Column {
                width: parent.width
                spacing: root.actionNoteGap
                OperatorButton { id: enableButton; objectName: "pluginModuleEnabled"; width: parent.width; height: root.controlHeight; text: root.enableText; primary: root.enablePrimary; enabled: root.enableEnabled; font.family: root.fontFamily; font.pixelSize: Math.max(root.actionSize, 9.5 / Math.max(0.1, hudScale)); textColor: root.textColor }
                OperatorText { width: parent.width; height: Math.max(root.actionNoteMinimumHeight, implicitHeight); text: root.footerText; size: root.actionNoteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone; horizontalAlignment: Text.AlignHCenter }
            }
        }
        OperatorText {
            Layout.columnSpan: moduleGrid.columns
            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0
            visible: root.usageExpanded; text: root.usageText
            color: root.mutedColor; font.pixelSize: root.noteSize; wrapMode: Text.Wrap
        }
    }
}
