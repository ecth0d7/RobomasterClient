import QtQuick
import QtQuick.Layouts

// One stable input-grant row. Robot/source/use mappings stay in ordinary QML.
Item {
    id: root
    implicitWidth: 1000
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias sourceControl: sourceField.inputControl
    property alias itemControl: itemField.inputControl
    property alias robotControl: robotField.selectControl
    property alias localUseControl: localUseCheck
    property alias externalUseControl: externalUseCheck
    property alias removeControl: removeButton
    property string sourceText: ""
    property string itemText: ""
    property var robotTitles: []
    property int robotIndex: -1
    property string robotDisplay: "尚未选择来源机器人"
    property string robotHint: ""
    property bool editable: false
    property bool localUse: false
    property bool externalUse: false
    property int formColumns: width >= 1040 ? 3 : width >= 650 ? 2 : 1
    property real fieldSpacing: 8
    property real actionSpacing: 12
    property real columnGap: 12
    property real controlHeight: 38
    property real noteSize: 12
    property real inputSize: 14
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.fieldSpacing
        GridLayout {
            width: parent.width
            columns: root.formColumns
            columnSpacing: root.columnGap
            rowSpacing: root.fieldSpacing
            OperatorStartupFieldForm {
                id: sourceField
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                label: "来源ID"
                value: root.sourceText
                hint: "实际来源的精确标识。"
                maximumLength: 96
                editable: root.editable
                controlHeight: root.controlHeight
                labelSize: root.noteSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
            }
            OperatorStartupFieldForm {
                id: itemField
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                label: "数据项ID"
                value: root.itemText
                hint: "实际数据项的精确标识。"
                maximumLength: 96
                editable: root.editable
                controlHeight: root.controlHeight
                labelSize: root.noteSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
            }
            OperatorAdviceSetupSelectForm {
                id: robotField
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                label: "来源机器人范围"
                choices: root.robotTitles
                selectedIndex: root.robotIndex
                selectionText: root.robotDisplay
                hint: root.robotHint
                editable: root.editable
                fieldSpacing: root.fieldSpacing
                controlHeight: root.controlHeight
                noteSize: root.noteSize
                inputSize: root.inputSize
                textColor: root.textColor
                mutedColor: root.mutedColor
                fontFamily: root.fontFamily
            }
        }
        Flow {
            width: parent.width
            spacing: root.actionSpacing
            OperatorCheckBox { id: localUseCheck; width: Math.min(250, parent.width); height: root.controlHeight; text: "允许本机模型用途"; checked: root.localUse; enabled: root.editable; font.family: root.fontFamily }
            OperatorCheckBox { id: externalUseCheck; width: Math.min(260, parent.width); height: root.controlHeight; text: "允许外部模型用途"; checked: root.externalUse; enabled: root.editable; font.family: root.fontFamily }
            OperatorButton { id: removeButton; width: Math.min(156, parent.width); height: root.controlHeight; text: "移除此输入项"; enabled: root.editable; font.family: root.fontFamily }
        }
        Rectangle { width: parent.width; height: 1; color: root.separatorColor }
    }
}
