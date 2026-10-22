import QtQuick
import QtQuick.Controls
import "OperatorDiscoveryData.js" as Discovery

Rectangle {
    id: root
    // displayView只来自宿主renderer边界；旧raw discoveryHudItems不再直接进入活动提示。
    property var displayView: ({active:[],markers:[],history:[]})
    property bool previewOnly: false
    property bool designPlaceholder: false
    readonly property var visibleItems: displayView?.active ?? []
    readonly property var firstItem: visibleItems[0] ?? null
    readonly property bool displayable: visibleItems.length > 0
    property color priorityColor: firstItem?.priority === 3 && firstItem?.measurement_validation === "validated"
        ? Theme.red : firstItem?.priority >= 2 ? Theme.warning : Theme.text
    readonly property string explanation: designPlaceholder ? "布局参考；生产投影未接通时不会出现本卡片。" : Discovery.description(firstItem)
    signal detailsRequested
    objectName: "discoveriesHud"
    width: 340
    height: 104
    visible: designPlaceholder || displayable
    color: Theme.hudSurface
    radius: 3
    OperatorOutline {}
    Accessible.role: Accessible.StaticText
    Accessible.name: explanation
    HoverHandler { id: cardHover }
    ToolTip.visible: cardHover.hovered && !detailsButton.hovered
    ToolTip.delay: 600
    ToolTip.text: explanation
    OperatorText {
        x:10;y:4;width:parent.width-82;height:24;clip:true;size:12
        text: root.designPlaceholder ? "Designer · 发现布局" : (root.firstItem?.mock === true ? "感知发现 · mock" : "感知发现")
            + (root.firstItem?.priority === 3 ? " · 紧急" : root.firstItem?.priority === 2 ? " · 关注" : "")
        color:root.priorityColor
    }
    Button {
        id: detailsButton
        objectName: "discoveryDetailsButton"
        x:parent.width-66;y:4;width:56;height:24
        Accessible.name: "查看发现来源、时效和排除记录"
        contentItem: OperatorText { text:"来源";size:10;horizontalAlignment:Text.AlignHCenter }
        background: Rectangle {
            radius:2;color:detailsButton.hovered || detailsButton.down ? Theme.hudHover : "transparent"
            OperatorOutline { color:detailsButton.activeFocus ? Theme.green : Theme.hudBorder }
        }
        onClicked: root.detailsRequested()
    }
    OperatorText {
        x:10;y:28;width:parent.width-20;height:24;clip:true;size:13
        text:root.designPlaceholder ? "经宿主接纳的新鲜发现摘要" : (root.firstItem?.summary ?? "").replace(/\s+/g," ").trim()
        color:root.priorityColor
    }
    OperatorText {
        x:10;y:52;width:parent.width-20;height:24;clip:true;size:10;color:Theme.muted
        text:root.designPlaceholder ? "来源机器人 · 类别 · 置信度 · 测量核验" : root.firstItem === null ? "" : root.firstItem.source_robot + "号 · "
            + Discovery.kind(root.firstItem.source_kind) + " · " + Discovery.confidence(root.firstItem.confidence)
            + " · " + (root.firstItem.measurement_validation === "validated" ? "测量已核" : "测量未核")
    }
    OperatorText {
        x:10;y:76;width:parent.width-20;height:24;clip:true;size:10;color:Theme.muted
        text:root.designPlaceholder ? "本机／队友 · 源龄／接收龄 · 剩余窗口" : root.firstItem === null ? "" : (root.firstItem.display_channel === "local" ? "本机" : "队友")
            + (root.visibleItems.length > 1 ? " " + root.visibleItems.length + "项" : "")
            + " · 源" + Discovery.age(root.firstItem.source_age_ms) + " · 收" + Discovery.age(root.firstItem.receive_age_ms)
            + " · 余" + Discovery.age(root.firstItem.display_remaining_ms)
    }
}
