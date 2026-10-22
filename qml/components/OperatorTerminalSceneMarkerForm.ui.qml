import QtQuick

// 目标的几何外观。默认没有目标；朝向绘制与原生数据绑定在普通QML包装内。
Item {
    id: root
    objectName: "terminalSceneMarkerForm"
    implicitWidth: anchorX + labelOffsetX + labelWidth
    implicitHeight: Math.max(anchorY * 2, headingSize, labelHeight)
    width: implicitWidth
    height: implicitHeight
    property alias headingContainer: headingSlot
    property bool markerVisible: false
    property string labelText: ""
    property real anchorX: 14
    property real anchorY: 14
    property real markerSize: 10
    property real headingSize: 28
    property real headingStrokeWidth: 2
    property real labelOffsetX: 10
    property real labelOffsetY: -12
    property real labelWidth: 160
    property real labelHeight: 24
    property real labelSize: 11
    property color markerColor: Theme.green
    property color headingColor: Theme.green
    property color textColor: Theme.text
    property string fontFamily: Theme.fontFamily

    Rectangle {
        x: root.anchorX - width / 2
        y: root.anchorY - height / 2
        width: root.markerSize
        height: root.markerSize
        radius: width / 2
        color: root.markerColor
        visible: root.markerVisible
    }
    Item {
        id: headingSlot
        x: root.anchorX - width / 2
        y: root.anchorY - height / 2
        width: root.headingSize
        height: root.headingSize
        visible: root.markerVisible
    }
    OperatorText {
        x: root.anchorX + root.labelOffsetX
        y: root.anchorY + root.labelOffsetY
        width: root.labelWidth
        height: root.labelHeight
        visible: root.markerVisible
        text: root.labelText
        size: root.labelSize
        color: root.textColor
        font.family: root.fontFamily
    }
}
