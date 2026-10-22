import QtQuick
import QtQuick.Layouts

// One grant's appearance. Purpose controls and edits come from a stable
// ordinary-wrapper delegate; this Form cannot authorize or mutate a field.
Item {
    id: root
    objectName: "teamSetupGrantRowForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias sourceControl: sourceField.inputControl
    property alias itemControl: itemField.inputControl
    property alias removeControl: removeButton
    property string sourceValue: ""
    property string itemValue: ""
    property bool inputEditable: false
    property bool removeEnabled: false
    property int purposeCount: 0
    property Component purposeDelegate: null
    readonly property real purposeDelegateWidth: Math.max(0, (purposeFlow.width - root.purposeSpacing * (root.purposeColumns - 1)) / root.purposeColumns)
    readonly property int fieldColumns: width >= root.fieldBreakpoint ? 3 : 1
    readonly property int purposeColumns: width >= root.purposeWideBreakpoint ? 5 : width >= root.purposeCompactBreakpoint ? 2 : 1
    property real fieldSpacing: 8
    property real columnGap: 12
    property real fieldBreakpoint: 600
    property real purposeWideBreakpoint: 760
    property real purposeCompactBreakpoint: 420
    property real purposeSpacing: 8
    property real removeWidth: 156
    property real controlHeight: 38
    property real labelHeight: 26
    property real labelGap: 4
    property real hintGap: 8
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real labelSize: 12
    property real noteSize: 11
    property real inputSize: 14
    property real hintSize: root.noteSize
    property real separatorHeight: 1
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.fieldSpacing
        GridLayout {
            width: parent.width
            columns: root.fieldColumns
            columnSpacing: root.columnGap
            rowSpacing: root.fieldSpacing
            OperatorStartupFieldForm {
                id: sourceField
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                label: "来源ID"
                value: root.sourceValue
                hint: "与本机或队友实际来源一致。"
                maximumLength: 96
                editable: root.inputEditable
                labelHeight: root.labelHeight; labelGap: root.labelGap; controlHeight: root.controlHeight
                hintGap: root.hintGap; minimumHintHeight: root.minimumHintHeight; hintBottomPadding: root.hintBottomPadding
                labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                textColor: root.textColor; secondaryTextColor: root.secondaryTextColor; warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.separatorColor
                fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
            }
            OperatorStartupFieldForm {
                id: itemField
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                label: "数据项ID"
                value: root.itemValue
                hint: "填写具体项；不使用通配符。"
                maximumLength: 96
                editable: root.inputEditable
                labelHeight: root.labelHeight; labelGap: root.labelGap; controlHeight: root.controlHeight
                hintGap: root.hintGap; minimumHintHeight: root.minimumHintHeight; hintBottomPadding: root.hintBottomPadding
                labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                textColor: root.textColor; secondaryTextColor: root.secondaryTextColor; warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.separatorColor
                fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
            }
            OperatorButton {
                id: removeButton
                Layout.fillWidth: root.fieldColumns === 1
                Layout.minimumWidth: 0
                Layout.preferredWidth: root.removeWidth
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: root.fieldColumns === 3 ? Math.max(sourceField.inputControl.y, itemField.inputControl.y) : 0
                height: root.controlHeight
                text: "移除此字段"
                enabled: root.removeEnabled
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            }
        }
        Flow {
            id: purposeFlow
            width: parent.width
            spacing: root.purposeSpacing
            visible: root.purposeCount > 0
            Repeater { model: root.purposeCount; delegate: root.purposeDelegate }
        }
        Rectangle { width: parent.width; height: root.separatorHeight; color: root.separatorColor }
    }
}
