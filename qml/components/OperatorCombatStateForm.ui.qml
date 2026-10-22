import QtQuick

// 仅绘制已计算的状态；缺省不假定收到脱战或战斗状态。
Item {
    id: root
    property bool currentStateVisible: false
    property bool outOfCombat: false
    property string labelText: ""
    property color accent: Theme.muted
    property url combatIconSource: "../resources/player/my_robot/combat_icon.png"
    property url outIconSource: "../resources/player/my_robot/outofcombat_icon.png"
    property url iconSource: root.currentStateVisible ? (root.outOfCombat ? root.outIconSource : root.combatIconSource) : ""
    // Creator 对 rect 没有数值编辑器；这四项用于可视化调整素材裁剪。
    property real combatCropX: 19
    property real combatCropY: 16
    property real combatCropWidth: 32
    property real combatCropHeight: 44
    property real outCropX: 20
    property real outCropY: 21
    property real outCropWidth: 33
    property real outCropHeight: 28
    property real iconCropX: root.outOfCombat ? root.outCropX : root.combatCropX
    property real iconCropY: root.outOfCombat ? root.outCropY : root.combatCropY
    property real iconCropWidth: root.outOfCombat ? root.outCropWidth : root.combatCropWidth
    property real iconCropHeight: root.outOfCombat ? root.outCropHeight : root.combatCropHeight
    property rect iconClipRect: Qt.rect(root.iconCropX, root.iconCropY,
                                       root.iconCropWidth, root.iconCropHeight)
    property real iconLeft: 0
    property real iconTop: 4
    property real iconWidth: 18
    property real iconHeight: 18
    property real labelIconInset: 24
    property real labelTop: 0
    property real labelHeight: root.height
    property real labelSize: 12
    property string fontFamily: Theme.fontFamily
    property alias iconControl: icon
    property alias labelControl: label
    width: 112
    height: 26

    Image {
        id: icon
        x: root.iconLeft
        y: root.iconTop
        width: root.iconWidth
        height: root.iconHeight
        visible: root.currentStateVisible
        source: root.iconSource
        sourceClipRect: root.iconClipRect
        fillMode: Image.PreserveAspectFit
        mipmap: true
        Accessible.ignored: true
    }
    OperatorText {
        id: label
        x: root.currentStateVisible ? root.labelIconInset : 0
        y: root.labelTop
        width: parent.width - x
        height: root.labelHeight
        text: root.labelText
        font.family: root.fontFamily
        size: root.labelSize
        color: root.accent
        clip: true
    }
}
