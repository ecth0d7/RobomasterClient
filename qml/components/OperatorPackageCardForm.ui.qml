import QtQuick
import QtQuick.Layouts

// 单个包的实际绘制；不装载包、不推断运行状态，选择意图由包装接线。
Item {
    id: root
    objectName: "packageCardForm"
    implicitWidth: 760
    implicitHeight: cardGrid.implicitHeight + root.contentMargin * 2 + root.separatorHeight
    width: implicitWidth
    height: implicitHeight
    property alias selectControl: selectButton
    property string titleText: "Designer绘制参考 · 未接通插件"
    property string identityText: "没有真实包身份或版本"
    property string stateText: "未接通原生目录；没有运行状态"
    property string errorText: ""
    property bool selected: false
    property bool selectEnabled: false
    property string selectText: "未接通"
    property real contentMargin: 12
    property real rowSpacing: 6
    property real columnGap: 12
    property real breakpoint: 720
    property real actionWidth: 170
    property real controlHeight: 38
    property real separatorHeight: 1
    property real titleSize: 14
    property real noteSize: 12
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
    property color selectedColor: Theme.green
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    GridLayout {
        id: cardGrid
        x: root.contentMargin
        y: root.contentMargin
        width: Math.max(0, root.width - root.contentMargin * 2)
        columns: width >= root.breakpoint ? 2 : 1
        columnSpacing: root.columnGap
        rowSpacing: root.rowSpacing
        Column {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: root.rowSpacing
            OperatorText { width: parent.width; height: implicitHeight; text: root.titleText; size: root.titleSize; color: root.selected ? root.selectedColor : root.textColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.identityText; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.stateText; size: root.noteSize; color: root.errorText.length > 0 ? root.warningColor : root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; visible: root.errorText.length > 0; text: root.errorText; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        }
        OperatorButton {
            id: selectButton
            objectName: "packageCardSelect"
            Layout.preferredWidth: cardGrid.width >= root.breakpoint ? root.actionWidth : -1
            Layout.fillWidth: cardGrid.width < root.breakpoint
            Layout.minimumWidth: 0
            Layout.preferredHeight: root.controlHeight
            Layout.alignment: Qt.AlignTop
            text: root.selectText
            enabled: root.selectEnabled
            font.family: root.fontFamily
        }
    }
    Rectangle { y: root.height - height; width: root.width; height: root.separatorHeight; color: root.separatorColor }
}
