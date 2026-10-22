import QtQuick
import QtQuick.Shapes

// 本机鼠标的可编辑矢量层；方向与时效由行为层提供，不代表机器人朝向。
Item {
    id: root
    property bool known: false
    property bool leftDown: false
    property bool rightDown: false
    property bool middleDown: false
    property int motionX: 0
    property int motionY: 0
    property int wheelDirection: 0
    property real referenceWidth: 32
    property real referenceHeight: 28
    property real bodyLeft: 10
    property real bodyRight: 22
    property real bodyTop: 5
    property real bodyBottom: 24
    property real cornerWidth: 4
    property real upperCornerHeight: 4
    property real lowerCornerWidth: 5
    property real lowerCornerHeight: 5
    property real centerX: (root.bodyLeft + root.bodyRight) / 2
    property real buttonDividerY: 13
    property real pressedBottomY: 14
    property real bodyStroke: 0.7
    property real wheelWidth: 2
    property real wheelHeight: 4
    property real wheelTop: 7
    property real wheelStroke: 1.3
    property real wheelUpTop: 6
    property real wheelUpBottom: 10
    property real wheelDownTop: 10
    property real wheelDownBottom: 12
    property real arrowHalfWidth: 3
    property real arrowDepth: 3
    property real topArrowY: 0
    property real bottomArrowY: 28
    property real sideArrowY: 14
    property real leftArrowX: 3
    property real rightArrowX: 29
    property real sideArrowDepth: 4
    property color knownBodyColor: "#72877c"
    property color unknownBodyColor: "#43514a"
    property color pressedColor: "#b5cec0"
    property color knownStrokeColor: "#c3d1c7"
    property color unknownStrokeColor: "#718078"
    property color wheelColor: "#394b41"
    property color arrowColor: "#dce8df"
    property color wheelMotionColor: "#e4ebde"
    implicitWidth: 32
    implicitHeight: 28
    width: root.implicitWidth
    height: root.implicitHeight
    Accessible.ignored: true
    Item {
        width: root.referenceWidth
        height: root.referenceHeight
        transform: Scale {
            xScale: root.width / Math.max(1, root.referenceWidth)
            yScale: root.height / Math.max(1, root.referenceHeight)
        }
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillColor: root.known ? root.knownBodyColor : root.unknownBodyColor
                startX: root.bodyLeft + root.cornerWidth; startY: root.bodyTop
                PathLine { x: root.bodyRight - root.cornerWidth; y: root.bodyTop }
                PathQuad { x: root.bodyRight; y: root.bodyTop + root.upperCornerHeight; controlX: root.bodyRight; controlY: root.bodyTop }
                PathLine { x: root.bodyRight; y: root.bodyBottom - root.lowerCornerHeight }
                PathQuad { x: root.bodyRight - root.lowerCornerWidth; y: root.bodyBottom; controlX: root.bodyRight; controlY: root.bodyBottom }
                PathLine { x: root.bodyLeft + root.lowerCornerWidth; y: root.bodyBottom }
                PathQuad { x: root.bodyLeft; y: root.bodyBottom - root.lowerCornerHeight; controlX: root.bodyLeft; controlY: root.bodyBottom }
                PathLine { x: root.bodyLeft; y: root.bodyTop + root.upperCornerHeight }
                PathQuad { x: root.bodyLeft + root.cornerWidth; y: root.bodyTop; controlX: root.bodyLeft; controlY: root.bodyTop }
            }
            // 按钮轮廓沿同一外形裁切，按下时不会露出矩形角。
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillColor: root.leftDown ? root.pressedColor : "transparent"
                startX: root.bodyLeft + root.cornerWidth; startY: root.bodyTop
                PathLine { x: root.centerX; y: root.bodyTop }
                PathLine { x: root.centerX; y: root.pressedBottomY }
                PathLine { x: root.bodyLeft; y: root.pressedBottomY }
                PathLine { x: root.bodyLeft; y: root.bodyTop + root.upperCornerHeight }
                PathQuad { x: root.bodyLeft + root.cornerWidth; y: root.bodyTop; controlX: root.bodyLeft; controlY: root.bodyTop }
            }
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillColor: root.rightDown ? root.pressedColor : "transparent"
                startX: root.centerX; startY: root.bodyTop
                PathLine { x: root.bodyRight - root.cornerWidth; y: root.bodyTop }
                PathQuad { x: root.bodyRight; y: root.bodyTop + root.upperCornerHeight; controlX: root.bodyRight; controlY: root.bodyTop }
                PathLine { x: root.bodyRight; y: root.pressedBottomY }
                PathLine { x: root.centerX; y: root.pressedBottomY }
                PathLine { x: root.centerX; y: root.bodyTop }
            }
            ShapePath {
                strokeWidth: root.bodyStroke
                strokeColor: root.known ? root.knownStrokeColor : root.unknownStrokeColor
                fillColor: "transparent"
                startX: root.bodyLeft + root.cornerWidth; startY: root.bodyTop
                PathLine { x: root.bodyRight - root.cornerWidth; y: root.bodyTop }
                PathQuad { x: root.bodyRight; y: root.bodyTop + root.upperCornerHeight; controlX: root.bodyRight; controlY: root.bodyTop }
                PathLine { x: root.bodyRight; y: root.bodyBottom - root.lowerCornerHeight }
                PathQuad { x: root.bodyRight - root.lowerCornerWidth; y: root.bodyBottom; controlX: root.bodyRight; controlY: root.bodyBottom }
                PathLine { x: root.bodyLeft + root.lowerCornerWidth; y: root.bodyBottom }
                PathQuad { x: root.bodyLeft; y: root.bodyBottom - root.lowerCornerHeight; controlX: root.bodyLeft; controlY: root.bodyBottom }
                PathLine { x: root.bodyLeft; y: root.bodyTop + root.upperCornerHeight }
                PathQuad { x: root.bodyLeft + root.cornerWidth; y: root.bodyTop; controlX: root.bodyLeft; controlY: root.bodyTop }
            }
            ShapePath {
                strokeWidth: root.bodyStroke
                strokeColor: root.known ? root.knownStrokeColor : root.unknownStrokeColor
                capStyle: ShapePath.FlatCap; fillColor: "transparent"
                startX: root.bodyLeft; startY: root.buttonDividerY
                PathLine { x: root.bodyRight; y: root.buttonDividerY }
                PathMove { x: root.centerX; y: root.bodyTop }
                PathLine { x: root.centerX; y: root.buttonDividerY }
            }
        }
        Rectangle {
            x: root.centerX - root.wheelWidth / 2; y: root.wheelTop
            width: root.wheelWidth; height: root.wheelHeight
            color: root.middleDown ? root.pressedColor : root.wheelColor
        }
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillColor: root.motionY < 0 ? root.arrowColor : "transparent"
                startX: root.centerX; startY: root.topArrowY
                PathLine { x: root.centerX - root.arrowHalfWidth; y: root.topArrowY + root.arrowDepth }
                PathLine { x: root.centerX + root.arrowHalfWidth; y: root.topArrowY + root.arrowDepth }
                PathLine { x: root.centerX; y: root.topArrowY }
            }
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillColor: root.motionY > 0 ? root.arrowColor : "transparent"
                startX: root.centerX; startY: root.bottomArrowY
                PathLine { x: root.centerX - root.arrowHalfWidth; y: root.bottomArrowY - root.arrowDepth }
                PathLine { x: root.centerX + root.arrowHalfWidth; y: root.bottomArrowY - root.arrowDepth }
                PathLine { x: root.centerX; y: root.bottomArrowY }
            }
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillColor: root.motionX < 0 ? root.arrowColor : "transparent"
                startX: root.leftArrowX; startY: root.sideArrowY
                PathLine { x: root.leftArrowX + root.sideArrowDepth; y: root.sideArrowY - root.arrowHalfWidth }
                PathLine { x: root.leftArrowX + root.sideArrowDepth; y: root.sideArrowY + root.arrowHalfWidth }
                PathLine { x: root.leftArrowX; y: root.sideArrowY }
            }
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillColor: root.motionX > 0 ? root.arrowColor : "transparent"
                startX: root.rightArrowX; startY: root.sideArrowY
                PathLine { x: root.rightArrowX - root.sideArrowDepth; y: root.sideArrowY - root.arrowHalfWidth }
                PathLine { x: root.rightArrowX - root.sideArrowDepth; y: root.sideArrowY + root.arrowHalfWidth }
                PathLine { x: root.rightArrowX; y: root.sideArrowY }
            }
            // 不为手册中语义未证实的旁线编造状态；这里只显示已知滚轮增量。
            ShapePath {
                strokeWidth: root.wheelStroke
                strokeColor: root.known && root.wheelDirection !== 0 ? root.wheelMotionColor : "transparent"
                capStyle: ShapePath.FlatCap; fillColor: "transparent"
                startX: root.centerX
                startY: root.wheelDirection > 0 ? root.wheelUpTop : root.wheelDownTop
                PathLine { x: root.centerX; y: root.wheelDirection > 0 ? root.wheelUpBottom : root.wheelDownBottom }
            }
        }
    }
}
