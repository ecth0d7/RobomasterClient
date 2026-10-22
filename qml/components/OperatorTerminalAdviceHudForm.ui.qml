import QtQuick
import QtQuick.Controls

// 只绘制固定信息槽；生产数据、时效和交互由同名行为组件接入。
Rectangle {
    id: root
    property alias detailsControl: detailsButton
    property string priorityText: "Designer布局参考 · 非实时建议"
    property string summaryText: "摘要文字槽 · 非比赛数据"
    property string reasonText: "依据文字槽 · 非模型结果"
    property string provenanceText: "来源机器人／提供者文字槽"
    property string modelText: "模型／生成宿主文字槽"
    property string snapshotText: "输入范围／快照标识文字槽"
    property string freshnessText: "接收年龄／输入年龄／剩余寿命文字槽"
    property string voiceText: "语音路由／队列状态槽 · 非播放确认"
    property string detailsText: "详情"
    property string detailsAccessibleName: "查看建议依据、来源与输入快照"
    property string fontFamily: Theme.fontFamily
    property color surfaceColor: Theme.hudSurface
    property color outlineColor: Theme.hudBorder
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
    property color priorityColor: Theme.green
    property color hoverColor: Theme.hudHover
    property color focusColor: Theme.green
    property real contentMargin: 10
    property real headerTop: 8
    property real headerHeight: 24
    property real headerGap: 6
    property real slotGap: 4
    property real bottomMargin: 10
    property real stripeWidth: 3
    property real detailsWidth: 56
    property real detailsGap: 12
    property real summaryHeight: 34
    property real reasonHeight: 20
    property real metaHeight: 18
    property real sourceHeight: 2 * root.metaHeight
    property real prioritySize: 12
    property real summarySize: 13
    property real reasonSize: 11
    property real metaSize: 10
    property real detailsSize: 10
    property int summaryLines: 2
    property int reasonLines: 1
    property real summaryTop: root.headerTop + root.headerHeight + root.headerGap
    property real reasonTop: root.summaryTop + root.summaryHeight + root.slotGap
    property real sourceTop: root.reasonTop + root.reasonHeight + root.slotGap
    property real snapshotTop: root.sourceTop + root.sourceHeight
    property real freshnessTop: root.snapshotTop + root.metaHeight
    property real voiceTop: root.freshnessTop + root.metaHeight
    property real reservedHeight: root.voiceTop + root.metaHeight + root.bottomMargin
    implicitWidth: 340
    implicitHeight: root.reservedHeight
    width: root.implicitWidth
    height: root.reservedHeight
    clip: true
    color: root.surfaceColor

    OperatorOutline { color: root.outlineColor }
    Rectangle { width: root.stripeWidth; height: parent.height; color: root.priorityColor; Accessible.ignored: true }
    OperatorText {
        x: root.contentMargin
        y: root.headerTop
        width: Math.max(0, parent.width - 2 * root.contentMargin - root.detailsWidth - root.detailsGap)
        height: root.headerHeight
        text: root.priorityText
        font.family: root.fontFamily
        size: root.prioritySize
        color: root.priorityColor
        Accessible.name: root.priorityText
    }
    Button {
        id: detailsButton
        objectName: "terminalAdviceHudDetails"
        x: parent.width - root.contentMargin - width
        y: root.headerTop
        width: root.detailsWidth
        height: root.headerHeight
        Accessible.name: root.detailsAccessibleName
        contentItem: OperatorText {
            text: root.detailsText
            font.family: root.fontFamily
            size: root.detailsSize
            color: root.textColor
            horizontalAlignment: Text.AlignHCenter
        }
        background: Rectangle {
            color: detailsButton.hovered ? root.hoverColor : "transparent"
            OperatorOutline { color: detailsButton.activeFocus ? root.focusColor : root.outlineColor }
        }
    }
    OperatorText {
        x: root.contentMargin; y: root.summaryTop
        width: Math.max(0, parent.width - 2 * root.contentMargin); height: root.summaryHeight
        text: root.summaryText; font.family: root.fontFamily; size: root.summarySize; color: root.textColor
        wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: root.summaryLines
        Accessible.name: root.summaryText
        clip: true
    }
    OperatorText {
        x: root.contentMargin; y: root.reasonTop
        width: Math.max(0, parent.width - 2 * root.contentMargin); height: root.reasonHeight
        text: root.reasonText; font.family: root.fontFamily; size: root.reasonSize; color: root.secondaryTextColor
        wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: root.reasonLines
        Accessible.name: root.reasonText
        clip: true
    }
    OperatorText {
        x: root.contentMargin; y: root.sourceTop
        width: Math.max(0, parent.width - 2 * root.contentMargin); height: root.metaHeight
        text: root.provenanceText; font.family: root.fontFamily; size: root.metaSize; color: root.secondaryTextColor
        Accessible.name: root.provenanceText
        clip: true
    }
    OperatorText {
        x: root.contentMargin; y: root.sourceTop + root.metaHeight
        width: Math.max(0, parent.width - 2 * root.contentMargin); height: Math.max(0, root.sourceHeight - root.metaHeight)
        text: root.modelText; font.family: root.fontFamily; size: root.metaSize; color: root.secondaryTextColor
        Accessible.name: root.modelText
        clip: true
    }
    OperatorText {
        x: root.contentMargin; y: root.snapshotTop
        width: Math.max(0, parent.width - 2 * root.contentMargin); height: root.metaHeight
        text: root.snapshotText; font.family: root.fontFamily; size: root.metaSize; color: root.secondaryTextColor
        elide: Text.ElideMiddle
        Accessible.name: root.snapshotText
        clip: true
    }
    OperatorText {
        x: root.contentMargin; y: root.freshnessTop
        width: Math.max(0, parent.width - 2 * root.contentMargin); height: root.metaHeight
        text: root.freshnessText; font.family: root.fontFamily; size: root.metaSize; color: root.secondaryTextColor
        Accessible.name: root.freshnessText
        clip: true
    }
    OperatorText {
        x: root.contentMargin; y: root.voiceTop
        width: Math.max(0, parent.width - 2 * root.contentMargin); height: root.metaHeight
        text: root.voiceText; font.family: root.fontFamily; size: root.metaSize; color: root.secondaryTextColor
        Accessible.name: root.voiceText
        clip: true
    }
}
