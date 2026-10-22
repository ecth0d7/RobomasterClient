import QtQuick
import QtQuick.Controls
import "OperatorBuffData.js" as Buff

OperatorPanelFrame {
    id: root
    property var records: []
    property bool previewOnly: false
    property bool projectionConnected: false
    property bool nativeConnected:false
    property bool localCollectionAvailable:false
    property int clientID: 0
    property int excludedCount: 0
    signal protocolRequested
    title: "自身增益 · 来源与时效"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    width: 1200
    height: 750
    OperatorText {
        width: parent.width; height: 26; size: 14
        text: "本机 " + root.clientID + " · " + (root.previewOnly ? "离线绘制 · mock · 不改变机器人状态" : root.localCollectionAvailable ? "本机服务器增益集合 · 原始MQTT保留最后一条" : root.records.some(r=>r.source_kind === "mqtt") || root.nativeConnected && !root.projectionConnected ? "MQTT最新增益 · 完整集合未提供" : root.projectionConnected ? "投影接口已启用 · 完整增益集合须由源端确认" : "增益快照生产端尚未接入 · 原始字段可独立查看")
            + (root.excludedCount > 0 ? " · 筛除 " + root.excludedCount + " 条异机/失效/冲突记录" : "")
            + (root.previewOnly && !root.projectionConnected && root.records.length === 0 ? " · 生产投影未接入" : "")
        color: root.previewOnly ? Theme.warning : Theme.text
    }
    OperatorText {
        y: 30; width: parent.width; height: 58; size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: "1攻击 · 2防御/易伤 · 3热量冷却 · 4底盘功率 · 5回血 · 6可兑换弹量 · 7地形预备。冷却是增加的速率，不能写成倍数；未知类型保留原值。"
        color: Theme.muted
    }
    OperatorScrollableColumn {
        objectName:"buffScroll"
        y: 98
        width: parent.width
        height: parent.height - y - 124
        Item {
            width: parent.width
            implicitHeight: Math.max(0, Math.ceil(root.records.length / 3) * 170 - 12)
            Repeater {
                model: root.records.length
                Rectangle {
                    id: row
                    required property int index
                    readonly property var record: root.records[index] ?? ({})
                    objectName:"buffDetail"+index
                    readonly property bool currentRecord: record.state === "fresh" && record.lifecycle === "active" && record.clock_verified === true
                    x: (index % 3) * (width + 12); y: Math.floor(index / 3) * 170
                    width: (parent.width - 24) / 3; height: 158
                    color: Theme.hudSurface
                    Accessible.role: Accessible.StaticText
                    Accessible.name: Buff.title(record) + " · " + Buff.value(record) + " · " + Buff.timeText(record)
                        + " · 机器人 " + record.robot_id + " · " + record.source_kind + " / " + record.source_id
                        + " · 快照 " + record.snapshot_id
                    HoverHandler { id: recordHover }
                    ToolTip.visible: recordHover.hovered
                    ToolTip.delay: 450
                    ToolTip.text: row.Accessible.name
                    OperatorOutline { color: Theme.hudBorder }
                    OperatorBuffGlyph { x: 12; y: 10; width: 32; height: 32; kind:row.record.record_kind==="terrain"?7:row.record.buff_type??0;terrainKind:row.record.terrain_kind??"";terrainPhase:row.record.terrain_phase??""; robotID:row.record.robot_id ?? 0; negative: (row.record.buff_level ?? 0) < 0; opacity: row.currentRecord ? 1 : 0.45 }
                    OperatorText { x: 54; y: 8; width: parent.width - 66; height: 28; text: Buff.title(row.record) + " · " + Buff.stateText(row.record); size: 14; color: row.currentRecord ? Theme.text : Theme.muted }
                    OperatorText { x: 12; y: 44; width: parent.width - 24; height: 34; text: Buff.value(row.record); numeric: true; size: 21; color: row.currentRecord ? Theme.text : Theme.muted }
                    Rectangle {
                        x: 12; y: 80; width: parent.width - 24; height: 3; color: Theme.line
                        visible: Buff.fraction(row.record) !== null
                        Rectangle {
                            property real displayedFraction: Buff.fraction(row.record) ?? 0
                            Behavior on displayedFraction {
                                enabled: row.record.state === "fresh" && row.record.time_unit === "s"
                                NumberAnimation { duration: Theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
                            }
                            width: parent.width * displayedFraction
                            height: parent.height
                            color: row.record.buff_type === 2 && row.record.buff_level < 0 ? Theme.warning : Theme.green
                        }
                    }
                    OperatorText { x: 12; y: 86; width: parent.width - 24; height: 30; text: "剩余 / 最大剩余 " + Buff.timeText(row.record); size: 12; color: Theme.muted }
                    OperatorText { x: 12; y: 122; width: parent.width - 24; height: 30; text: (row.record.source_kind==="local_shark_server"?"本机服务器":row.record.source_kind==="mqtt"?"MQTT":"选手端来源") + (Number.isFinite(row.record.age_ms) ? " · " + (row.record.age_ms / 1000).toFixed(1) + "秒前" : " · 逐字段接收"); size: 10; color: Theme.muted }
                }
            }
        }
    }
    OperatorText {
        y: 120; width: parent.width; height: 180
        visible: root.records.length === 0
        text:root.localCollectionAvailable ? "当前没有活动增益或地形状态。" : "没有可显示的本机增益记录。\n\n缺失、非本机、失联、过期或未核验记录不会补成0或“无增益”。原始Buff字段仍可查看。"
        wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 15; color: Theme.muted
    }
    OperatorText {
        y: parent.height - 108; width: parent.width; height: 64; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: "最大剩余时间不是总持续时间或TTL。单位未确认不倒数，缺失／冲突不画比例；旧／已结束仅留详情，100%防御不自动称无敌。"
        color: Theme.muted
    }
    OperatorButton { y: parent.height - height; height: 38; width: 210; text: "查看 Buff 原始字段"; onClicked: root.protocolRequested() }
}
