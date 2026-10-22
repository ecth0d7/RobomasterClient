import QtQuick
import "OperatorData.js" as Data
import "OperatorModuleData.js" as Modules
import "EventFormat.js" as Events

OperatorRoleCard {
    id: root
    objectName:"moduleDetailPanel"
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool connectedToPlayer: false
    property var bottomStatusDisplay: null
    readonly property var moduleDisplay: bottomStatusDisplay ?? Modules.view(telemetry,clientID,connectedToPlayer,null,"",false,Date.now(),previewOnly)
    property int selectedTab: 0
    readonly property var injury: telemetry?.robotInjury ?? ({})
    readonly property string killerState: Data.state(telemetry, "robotInjury", "killer_id")
    title: "受伤与模块 · " + (clientID || "未选身份")
    stateText: (previewOnly ? "mock · " : "选手端 · ")+(selectedTab === 0 ? "逐字段统计，不从伤害值推算模块状态"
        : selectedTab === 1 ? (moduleDisplay.native.subject.reason ? moduleDisplay.native.subject.reason+" · " : "")
            +"已收 "+moduleDisplay.native.present+"/11 · 新鲜 "+moduleDisplay.native.fresh
        : "在线／识别／供电／速率语义分开 · 无源不补值")
    width: 430
    // 16:9空中弹量从y636开始；224+396=620，保留16px间距，不能沿用430高遮住数字。
    height: 396
    function reading(key) { return Data.text(telemetry, "robotInjury", key) + (Data.state(telemetry, "robotInjury", key) === "stale" ? "旧" : ""); }
    Row {
        width: parent.width; spacing: 12
        OperatorButton { width: (parent.width - 24) / 3; height: 36; text: "受伤统计"; primary: root.selectedTab === 0; onClicked: root.selectedTab = 0 }
        OperatorButton { width: (parent.width - 24) / 3; height: 36; text: "模块 · 11项"; primary: root.selectedTab === 1; onClicked: root.selectedTab = 1 }
        OperatorButton { width: (parent.width - 24) / 3; height: 36; text: "HUD来源"; primary: root.selectedTab === 2; onClicked: root.selectedTab = 2 }
    }
    Row {
        y: 47; width: parent.width; visible: root.selectedTab === 0
        OperatorText { width: 150; height: 26; text: "该次存活累计"; size: 12; color: Theme.muted }
        OperatorText { width: parent.width - 150; height: 26; text: root.reading("total_damage"); numeric: true; size: 19; horizontalAlignment: Text.AlignRight; color: Data.state(root.telemetry, "robotInjury", "total_damage") === "fresh" ? Theme.text : Theme.muted }
    }
    Grid {
        y: 83; width: parent.width; columns: 2; columnSpacing: 12; rowSpacing: 6; visible: root.selectedTab === 0
        Repeater {
            model: [{key:"small_projectile_damage",label:"17mm弹丸"},{key:"large_projectile_damage",label:"42mm弹丸"},
                    {key:"collision_damage",label:"撞击"},{key:"dart_splash_damage",label:"飞镖溅射"},
                    {key:"module_offline_damage",label:"模块离线扣血"},{key:"offline_damage",label:"异常离线扣血"},
                    {key:"penalty_damage",label:"判罚扣血"},{key:"server_kill_damage",label:"服务器强制扣血"}]
            Item {
                required property var modelData
                width: (parent.width - 12) / 2; height: 36
                OperatorText { width: parent.width; height: 18; text: parent.modelData.label; size: 10; color: Theme.muted }
                OperatorText { y: 18; width: parent.width; height: 18; text: root.reading(parent.modelData.key); numeric: true; size: 14; color: Data.state(root.telemetry, "robotInjury", parent.modelData.key) === "fresh" ? Theme.text : Theme.muted }
            }
        }
    }
    OperatorText {
        y: 259; width: parent.width; height: 27; visible: root.selectedTab === 0; size: 11; color: Theme.muted
        text: "击杀者：" + (root.killerState === "missing" ? "—" : root.injury.killer_id === 0 ? "未检测到" : Events.robotName(root.injury.killer_id) + " · ID " + root.injury.killer_id) + (root.killerState === "stale" ? " · 旧" : "")
    }
    Grid {
        y: 49; width: parent.width; columns: 2; columnSpacing: 12; rowSpacing: 5; visible: root.selectedTab === 1
        Repeater {
            model: Modules.modules
            OperatorModuleCell {
                required property var modelData
                objectName:"nativeModule-"+modelData.key
                width: (parent.width - 12) / 2; height: 30
                label:modelData.full
                reading:root.moduleDisplay.native.fields[modelData.key]
            }
        }
    }
    Grid {
        y:45;width:parent.width;columns:2;columnSpacing:12;rowSpacing:4
        visible:root.selectedTab === 2
        Repeater {
            model:Modules.slots
            OperatorModuleCell {
                required property var modelData
                required property int index
                objectName:"hudSource-"+modelData.kind
                width:(parent.width-12)/2;height:40
                stacked:true
                label:root.moduleDisplay.hud[index].present ? root.moduleDisplay.hud[index].caption : modelData.label
                reading:root.moduleDisplay.hud[index]
            }
        }
    }
    OperatorText {
        y:parent.height-21;width:parent.width;height:21;visible:root.selectedTab !== 0;size:11;color:Theme.muted
        text:root.selectedTab === 1 ? "0离线 1在线 2安装异常（按离线）"
            : root.moduleDisplay.notes.length ? root.moduleDisplay.notes.length+"条来源资格提示 · 悬停查看"
            : "无源不显示 · 原生模块独立可用"
        HoverHandler {id:noteHover}
        OperatorDataToolTip {
            visible:noteHover.hovered
            text:root.moduleDisplay.notes.join("\n") || "可选显示视图默认未接通；不能从模块在线推断识别、供电、码率或控制器连接。"
        }
    }
}
