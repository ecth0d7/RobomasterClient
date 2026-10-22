import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorBuffData.js" as Buff

Item {
    id: root
    property var records: []
    property bool designPlaceholder: false
    readonly property var activeRecords: records.filter(Buff.hudEligible)
    readonly property bool displayable: activeRecords.length > 0
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property real badgeSize: Math.max(48,40/Math.max(0.1,hudScale))
    property real stride: badgeSize+6
    property real contentWidth: Math.min(activeRecords.length,5)*stride+(activeRecords.length>5?36:0)
    signal detailsRequested
    width: Math.max(badgeSize,contentWidth)
    height: badgeSize
    Repeater {
        model: Math.min(root.activeRecords.length,5)
        OperatorBuffBadge {
            required property int index
            x:index*root.stride; width:root.badgeSize; height:width
            record:root.activeRecords[index]??({})
            visible:root.activeRecords[index]!==undefined
            enabled:!root.designPlaceholder
            onClicked:root.detailsRequested()
        }
    }
    Button {
        objectName:"buffOverflow"
        x:5*root.stride; width:36; height:root.badgeSize; padding:0
        visible:root.activeRecords.length>5
        enabled:!root.designPlaceholder
        background:Item {
            Rectangle {
                anchors.horizontalCenter:parent.horizontalCenter
                anchors.bottom:parent.bottom;anchors.bottomMargin:5
                width:24;height:1;visible:parent.parent.activeFocus;color:Theme.green
            }
        }
        contentItem: OperatorText {
            text:"+"+(root.activeRecords.length-5)
            numeric:true;size:12;color:Theme.muted
            horizontalAlignment:Text.AlignHCenter
        }
        Accessible.name:"查看已知本机增益，共"+root.activeRecords.length+"项"
        onClicked:root.detailsRequested()
    }
    Row {
        spacing:6
        visible:root.designPlaceholder&&!root.displayable
        Repeater {
            model:3
            Image {
                width:root.badgeSize;height:width
                source:"../resources/engine-137/sprites/buff_2020_cirle_empty.png"
                fillMode:Image.PreserveAspectFit
                mipmap:true;Accessible.ignored:true
            }
        }
    }
}
