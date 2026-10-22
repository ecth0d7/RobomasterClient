import QtQuick

Item {
    id: root
    property string labelText: ""
    property color labelColor: Theme.muted
    property real labelSize: 11
    property string fontFamily: Theme.fontFamily
    property alias labelControl: label
    width: (354 - 16) / 3
    height: 24

    OperatorText {
        id: label
        anchors.fill: parent
        text: root.labelText
        size: root.labelSize
        font.family: root.fontFamily
        color: root.labelColor
        clip: true
    }
}
