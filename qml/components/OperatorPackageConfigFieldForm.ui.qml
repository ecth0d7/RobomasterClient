import QtQuick
import QtQuick.Controls

// Typed field drawing only. Presence, values, validation and persistence are
// supplied by the behavior wrapper; this Form never calls a native service.
Item {
    id: root
    implicitWidth: 760
    implicitHeight: fieldColumn.implicitHeight + 2 * root.contentMargin
    width: implicitWidth
    height: implicitHeight

    property alias includeControl: includeCheck
    property alias booleanControl: booleanCheck
    property alias enumControl: enumSelect
    property alias inputControl: scalarInput
    property alias scalarControl: scalarInput
    property alias textAreaControl: structuredInput
    property alias structuredControl: structuredInput
    property string fieldTitle: "插件参数（可选）"
    property string fieldDescription: "Designer绘制参考 · 此表单不保存参数或启用插件。"
    property string editorKind: "string"
    property bool requiredField: false
    property bool includedField: false
    property bool inputEditable: false
    property bool inclusionEditable: false
    property bool booleanValue: false
    property string booleanLabel: "参数开关值"
    property var enumTitles: []
    property int enumIndex: -1
    property string enumDisplayText: "尚未选择"
    property string enumEmptyText: "尚未选择"
    property string scalarText: ""
    property string structuredText: ""
    property string inputLabel: "插件参数"
    property string inputPlaceholder: ""
    property int scalarMaximumLength: 4096
    property string presenceText: "未设置；保存时省略此可选参数。"
    property string typeHint: "文字参数；由原生宿主执行最终校验。"
    property bool presenceWarning: false
    property real contentMargin: 0
    property real fieldSpacing: 8
    property real inputHeight: 38
    property real includeHeight: 38
    property real structuredHeight: 136
    property real labelSize: 13
    property real noteSize: 12
    property real inputSize: 14
    property real dividerThickness: 1
    property real dividerOpacity: 0.6
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color dividerColor: Theme.line
    property string fontFamily: Theme.fontFamily
    property string editorFontFamily: Theme.fontFamily
    property string structuredFontFamily: Theme.numberFamily

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        z: -1
    }
    Column {
        id: fieldColumn
        x: root.contentMargin
        y: root.contentMargin
        width: root.width - 2 * root.contentMargin
        spacing: root.fieldSpacing
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: root.fieldTitle
            color: root.textColor
            size: root.labelSize
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: root.fieldDescription.length > 0
            text: root.fieldDescription
            color: root.mutedColor
            size: root.noteSize
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        OperatorCheckBox {
            id: includeCheck
            width: parent.width
            height: root.includeHeight
            visible: !root.requiredField
            text: "设置此可选参数"
            checked: root.includedField
            enabled: root.inclusionEditable
            textColor: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: root.presenceText.length > 0
            text: root.presenceText
            color: root.presenceWarning ? root.warningColor : root.mutedColor
            size: root.noteSize
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        OperatorCheckBox {
            id: booleanCheck
            width: parent.width
            height: root.inputHeight
            visible: root.editorKind === "boolean"
            text: root.booleanLabel
            checked: root.booleanValue
            enabled: root.inputEditable
            textColor: root.textColor
            Accessible.name: root.inputLabel + " · " + root.booleanLabel
            font.family: root.fontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
        OperatorSelect {
            id: enumSelect
            width: parent.width
            height: root.inputHeight
            visible: root.editorKind === "enum"
            label: root.inputLabel
            model: root.enumTitles
            currentIndex: root.enumIndex
            displayText: root.enumDisplayText
            emptyText: root.enumEmptyText
            enabled: root.inputEditable
            textColor: root.textColor
            font.family: root.editorFontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
        OperatorInput {
            id: scalarInput
            width: parent.width
            height: root.inputHeight
            visible: root.editorKind === "string" || root.editorKind === "integer" || root.editorKind === "number"
            label: root.inputLabel
            placeholderText: root.inputPlaceholder
            text: root.scalarText
            maximumLength: root.scalarMaximumLength
            enabled: root.inputEditable
            color: root.inputEditable ? root.textColor : root.mutedColor
            placeholderTextColor: root.mutedColor
            font.family: root.editorFontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
        ScrollView {
            id: structuredScroll
            width: parent.width
            height: root.structuredHeight
            visible: root.editorKind === "object" || root.editorKind === "array"
            clip: true
            contentWidth: availableWidth
            OperatorTextArea {
                id: structuredInput
                width: structuredScroll.availableWidth
                height: Math.max(root.structuredHeight, implicitHeight)
                label: root.inputLabel + " JSON"
                placeholderText: root.inputPlaceholder
                text: root.structuredText
                enabled: root.inputEditable
                color: root.inputEditable ? root.textColor : root.mutedColor
                placeholderTextColor: root.mutedColor
                numeric: true
                font.family: root.structuredFontFamily
                font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            }
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: root.typeHint.length > 0
            text: root.typeHint
            color: root.mutedColor
            size: root.noteSize
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Rectangle {
            width: parent.width
            height: root.dividerThickness
            color: root.dividerColor
            opacity: root.dividerOpacity
        }
    }
}
