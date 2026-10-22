import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorMessageData.js" as Messages

Item {
    id: root
    property var events: []
    property var robotEvents: []
    property bool robotMessagesVisible: true
    property bool raceMessagesVisible: true
    property bool raceSourceAvailable: false
    property bool robotSourceAvailable: false
    property int clientID: 0
    property int raceViewRevision: 0
    property int robotViewRevision: 0
    property bool previewOnly: false
    property bool designPlaceholder: false
    property double drawingNow: Date.now()
    property real borderWidth: Theme.hudStroke(Window.window?.ui?.layoutScale??1,false)
    readonly property var raceItems: raceSourceAvailable
        ? Messages.records(events,clientID,raceViewRevision,drawingNow,previewOnly) : []
    readonly property var robotItems: robotSourceAvailable
        ? Messages.records(robotEvents,clientID,robotViewRevision,drawingNow,previewOnly) : []
    readonly property bool displayable: raceSourceAvailable || robotSourceAvailable
    // 显隐本身依赖投影，更新时钟须延后到绑定求值之后，避免机器人单槽的循环绑定。
    function refreshClock() { drawingNow=Date.now(); }
    function scheduleClockRefresh() { Qt.callLater(root.refreshClock); }
    onEventsChanged: scheduleClockRefresh()
    onRobotEventsChanged: scheduleClockRefresh()
    onRaceSourceAvailableChanged: scheduleClockRefresh()
    onRobotSourceAvailableChanged: scheduleClockRefresh()
    onRaceViewRevisionChanged: scheduleClockRefresh()
    onRobotViewRevisionChanged: scheduleClockRefresh()
    onClientIDChanged: scheduleClockRefresh()
    onVisibleChanged: if(visible)scheduleClockRefresh()
    width: 384
    // 两个固定槽位始终保留几何；一张隐藏不让另一张、建议或头像跳动。
    height: 214
    Timer {
        interval:250;repeat:true
        running:root.visible && root.displayable && (root.raceItems.length>0 || root.robotItems.length>0)
        onTriggered:root.drawingNow=Date.now()
    }
    Repeater {
        model: ["系统消息", "机器人消息"]
        Rectangle {
            id: card
            required property string modelData
            required property int index
            readonly property var messages: index===0?root.raceItems:root.robotItems
            readonly property string channelExplanation: "本机最近通知；没有上游发生时间，不表示持续状态。"
                +(index===0?"来自选手端导出接收链路，发布者身份仍需宿主核验。":"机器人消息生产投影需独立提供，不依赖队伍共享插件或选手端连接。")
            y: index * 110
            width: root.width
            height: 104
            objectName:index===0?"raceMessages":"robotMessages"
            visible: (index===0?root.raceMessagesVisible:root.robotMessagesVisible)
                && (root.designPlaceholder || card.messages.length>0)
            color: "transparent"
            Rectangle {
                x:26;width:parent.width-26;height:parent.height
                radius:3;color:Theme.hudSurface;border.width:root.borderWidth;border.color:Theme.hudBorder
            }
            Rectangle {
                width:27;height:card.index===0?66:90
                radius:3;color:Theme.hudSurface;border.width:root.borderWidth;border.color:Theme.hudBorder
                OperatorText {
                    anchors.fill:parent;anchors.margins:2
                    text:card.index===0?"系\n统":"机\n器\n人"
                    size:11;style:Text.Normal;horizontalAlignment:Text.AlignHCenter
                    lineHeight:0.92;clip:true
                }
            }
            OperatorText {
                visible: root.designPlaceholder
                x: 36
                y: 5
                width: parent.width - 126
                height: 21
                text: root.designPlaceholder?"Designer · 布局参考":root.previewOnly?"mock · 本机接收":card.index===0?"选手端接收 · 未核验":"本机接收 · 独立来源"
                size: 10
                color: Theme.muted
                HoverHandler { id:headingHover }
                ToolTip.visible:headingHover.hovered
                ToolTip.delay:450
                ToolTip.text:card.channelExplanation
            }
            OperatorText {
                visible: root.designPlaceholder
                x:parent.width-80;y:5;width:70;height:21
                text:root.designPlaceholder?"布局参考":Messages.ageText(card.messages[card.messages.length-1],root.drawingNow)
                size:10;horizontalAlignment:Text.AlignRight;color:Theme.muted
            }
            Column {
                x: 36
                y: root.designPlaceholder ? 31 : 6
                width: parent.width - 46
                spacing: 2
                Repeater {
                    // 三个稳定文本对象；年龄刷新只更新属性，不按250ms重建行。
                    model: root.designPlaceholder ? 3 : 4
                    OperatorText {
                        id: notification
                        required property int index
                        readonly property var record: card.messages[index]
                        visible:record!==undefined
                        width: parent.width
                        height: 22
                        text:record?Messages.clockText(record)+" · "+record.text:""
                        size: 12
                        color: card.index===1?Theme.text
                            : record?.tone==="beneficial"?Theme.green:record?.tone==="adverse"?Theme.red:Theme.text
                        clip:true
                        Accessible.name:record?Messages.explanation(record,root.drawingNow):""
                        HoverHandler { id:notificationHover }
                        ToolTip.visible:notificationHover.hovered && record!==undefined
                        ToolTip.delay:450
                        ToolTip.text:record?Messages.explanation(record,root.drawingNow):""
                    }
                }
            }
            OperatorText {
                x: 36
                y: 40
                width: parent.width - 46
                height: 25
                visible: root.designPlaceholder && card.messages.length===0
                text: "仅布局参考 · 有效通知收到后显示"
                size: 11
                color: Theme.muted
            }
        }
    }
}
