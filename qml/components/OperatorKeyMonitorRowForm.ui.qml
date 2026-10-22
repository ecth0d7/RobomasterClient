import QtQuick
import QtQuick.Controls

Item {
    id: root
    property alias captureControl: captureButton
    property alias mouseGlyph: mouse
    property string labelText: "控制"
    property string fallbackText: "—"
    property var keyLabels: []
    property bool showKeyLabels: false
    property bool heldKeysActive: false
    property bool captureVisible: false
    property bool captureEnabled: false
    property bool captureIntended: false
    property string captureObjectName: ""
    property string captureDescription: ""
    property string fontFamily: Theme.fontFamily
    property string keyFontFamily: Theme.keyFontFamily
    property string keyStyleName: "Condensed"
    property string fallbackFontFamily: root.keyFontFamily
    property string fallbackStyleName: root.keyStyleName
    property real keySize: 14
    property real labelSize: 11
    property real keyGap: 2
    property real labelWidth: 27
    property real labelGap: 4
    property real textInset: 4
    property real mouseColumnWidth: 51
    property real mouseWidth: 32
    property real mouseHeight: 28
    property real mouseRightMargin: 13
    property real captureWidth: 38
    property real captureHeight: 28
    property real captureRightMargin: 10
    property real borderWidth: 0.7
    property real focusBorderWidth: 1
    property color labelColor: Theme.muted
    property color textColor: Theme.text
    property color idleSurface: "#88323b34"
    property color activeSurface: "#99435345"
    property color idleBorder: "#91afbcb2"
    property color activeBorder: "#a08da994"
    property color focusColor: Theme.green
    implicitWidth: 340
    implicitHeight: 22
    width: root.implicitWidth
    height: root.implicitHeight
    OperatorText {
        width: root.labelWidth; height: parent.height
        text: root.labelText; font.family: root.fontFamily
        size: root.labelSize; color: root.labelColor; style: Text.Normal; clip: true
    }
    Rectangle {
        id: keyFrame
        x: root.labelWidth + root.labelGap
        width: Math.max(0, root.width - root.mouseColumnWidth - x)
        height: root.height
        color: root.heldKeysActive ? root.activeSurface : root.idleSurface
        border.width: root.borderWidth
        border.color: root.heldKeysActive ? root.activeBorder : root.idleBorder
        clip: true
        OperatorText {
            x: root.textInset; width: Math.max(0, parent.width - 2 * x); height: parent.height
            visible: !root.showKeyLabels || root.keyLabels.length === 0
            text: root.fallbackText; size: root.keySize; color: root.textColor
            font.family: root.fallbackFontFamily; font.styleName: root.fallbackStyleName
            style: Text.Normal; clip: true
        }
        Row {
            x: root.textInset; height: parent.height; spacing: root.keyGap
            visible: root.showKeyLabels && root.keyLabels.length > 0
            Repeater {
                model: root.keyLabels.length
                OperatorText {
                    required property int index
                    text: root.keyLabels[index] || ""
                    width: implicitWidth; height: keyFrame.height
                    size: root.keySize; color: root.textColor
                    font.family: root.keyFontFamily; font.styleName: root.keyStyleName
                    style: Text.Normal; Accessible.ignored: true
                }
            }
        }
    }
    OperatorMouseInput {
        id: mouse
        x: root.width - root.mouseWidth - root.mouseRightMargin
        y: (root.height - root.mouseHeight) / 2
        width: root.mouseWidth; height: root.mouseHeight
    }
    Button {
        id: captureButton
        objectName: root.captureObjectName
        visible: root.captureVisible
        x: root.width - root.captureWidth - root.captureRightMargin
        y: (root.height - root.captureHeight) / 2
        width: root.captureWidth; height: root.captureHeight
        enabled: root.captureEnabled; padding: 0
        background: Rectangle {
            color: "transparent"; border.color: root.focusColor
            border.width: captureButton.activeFocus ? root.focusBorderWidth : 0
        }
        contentItem: Item {}
        Accessible.name: root.captureIntended ? "关闭持续键鼠捕获" : "启用持续键鼠捕获"
        Accessible.description: root.captureDescription
    }
}
