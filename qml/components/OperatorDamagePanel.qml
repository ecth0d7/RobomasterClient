import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorData.js" as Data
import "OperatorModuleData.js" as Modules

FocusScope {
    id: root
    objectName: "moduleDetailPanel"
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool connectedToPlayer: false
    property var bottomStatusDisplay: null
    readonly property var moduleDisplay: bottomStatusDisplay ?? Modules.view(telemetry,clientID,connectedToPlayer,null,"",false,Date.now(),previewOnly)
    // 2是从底部状态灯显式打开的来源工具；通常的~面板同时展示伤害与模块。
    property int selectedTab: 0
    property bool heldOpen: false
    property real availableHeight: 600
    readonly property bool compact: availableHeight < 480
    readonly property var injury: telemetry?.robotInjury ?? ({})
    readonly property var damageRows: [
        {key:"small_projectile_damage",label:"17mm 弹丸",icon:"17.png"},
        {key:"large_projectile_damage",label:"42mm 弹丸",icon:"42.png"},
        {key:"collision_damage",label:"撞击",icon:"sundry_icon.png"},
        {key:"module_offline_damage",label:"模块离线",icon:"sundry_icon.png"},
        {key:"penalty_damage",label:"警告",icon:"sundry_icon.png"}
    ]
    signal closeRequested
    width: selectedTab === 2 ? 430 : 310
    height: selectedTab === 2 ? 396 : Math.max(400,Math.min(600,availableHeight))
    onVisibleChanged: { if (!visible) heldOpen = false; }
    Keys.onEscapePressed: event => { event.accepted = true; root.closeRequested(); }
    Keys.onReleased: event => {
        if (heldOpen && event.key === Qt.Key_QuoteLeft && !event.isAutoRepeat) {
            event.accepted = true; root.closeRequested();
        }
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() { if (root.heldOpen && root.Window.window?.active !== true) root.closeRequested(); }
    }
    function reading(key) { return Data.text(telemetry,"robotInjury",key); }
    function percentage(key) {
        const value = injury[key], total = injury.total_damage;
        if (Data.state(telemetry,"robotInjury",key) !== "fresh"
            || Data.state(telemetry,"robotInjury","total_damage") !== "fresh"
            || !Number.isFinite(value) || !Number.isFinite(total) || value < 0 || total < value) return "—";
        return (total > 0 ? Math.round(value / total * 100) : 0) + "%";
    }
    Rectangle { anchors.fill: parent; color: Theme.hudSurface; visible: root.selectedTab !== 2; radius: 3 }
    Item {
        anchors.fill: parent
        visible: root.selectedTab !== 2
        OperatorText { x: 12; y: 12; width: parent.width - 24; height: 30; text: "伤害面板"; size: 22; minimumSize: 0 }
        Column {
            x: 12; y: root.compact ? 52 : 58; width: parent.width - 24; spacing: 4
            Repeater {
                model: root.damageRows
                Item {
                    id: damage
                    required property var modelData
                    width: parent.width; height: root.compact ? 24 : 30
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData.label + " " + root.reading(modelData.key) + "，占比 " + root.percentage(modelData.key)
                    Image { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; source: "../resources/player/panel/" + damage.modelData.icon; fillMode: Image.PreserveAspectFit; mipmap: true }
                    OperatorText { x: 30; width: 134; height: parent.height; text: damage.modelData.label; size: 16; minimumSize: 0 }
                    OperatorText { x: 165; width: 47; height: parent.height; text: root.reading(damage.modelData.key); size: 15; minimumSize: 0; numeric: true; fontSizeMode: Text.Fit; minimumPixelSize: 10; horizontalAlignment: Text.AlignRight }
                    OperatorText { x: 218; width: 10; height: parent.height; text: "|"; size: 14; minimumSize: 0; horizontalAlignment: Text.AlignHCenter }
                    OperatorText { x: 232; width: parent.width - x; height: parent.height; text: root.percentage(damage.modelData.key); size: 15; minimumSize: 0; numeric: true; horizontalAlignment: Text.AlignRight }
                    HoverHandler { id: damageHover }
                    ToolTip.visible: damageHover.hovered
                    ToolTip.text: damage.modelData.key + "：" + root.reading(damage.modelData.key)
                        + "\n累计伤害：" + root.reading("total_damage")
                        + "\n飞镖溅射：" + root.reading("dart_splash_damage")
                        + "；异常离线：" + root.reading("offline_damage")
                        + "；服务器强制扣血：" + root.reading("server_kill_damage")
                }
            }
        }
        OperatorText { x: 12; y: parent.height - (root.compact ? 216 : 250); width: parent.width - 24; height: 30; text: "模块状态"; size: 22; minimumSize: 0 }
        Grid {
            x: 12; y: parent.height - (root.compact ? 174 : 202); width: parent.width - 24; columns: 2; columnSpacing: 14; rowSpacing: root.compact ? 4 : 6
            Repeater {
                model: Modules.modules
                Item {
                    id: module
                    required property var modelData
                    objectName: "nativeModule-" + modelData.key
                    readonly property var reading: root.moduleDisplay.native.fields[modelData.key]
                    readonly property bool current: reading.state === "fresh" && reading.current
                    width: (parent.width - 14) / 2; height: root.compact ? 20 : 24
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData.full + "，" + reading.text
                    BorderImage {
                        anchors.fill: parent
                        source: "../resources/player/panel/sundry_" + (module.current && module.reading.value === 1 ? "online" : "offline") + ".png"
                        visible: module.current
                        border { left: 2; right: 2; top: 2; bottom: 2 }
                    }
                    Rectangle { anchors.fill: parent; visible: !module.current; color: "#111111"; border.color: "#666666"; border.width: 1 }
                    OperatorText {
                        x: 5; width: parent.width - 10; height: parent.height
                        text: module.modelData.key === "armor" ? "装甲汇总" : module.modelData.full
                        size: 14; minimumSize: 0; fontSizeMode: Text.Fit; minimumPixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        color: module.current ? Theme.text : Theme.muted
                    }
                    HoverHandler { id: moduleHover }
                    OperatorDataToolTip { visible: moduleHover.hovered; text: module.reading.description }
                }
            }
        }
        OperatorText {
            x: 12; y: parent.height - 26; width: parent.width - 24; height: 20
            text: root.heldOpen ? "松开~键收起面板" : "按住~键查看面板"
            size: 11; minimumSize: 0; horizontalAlignment: Text.AlignHCenter
        }
    }
    OperatorModuleInspector {
        anchors.fill: parent
        visible: root.selectedTab === 2
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        connectedToPlayer: root.connectedToPlayer
        bottomStatusDisplay: root.bottomStatusDisplay
        selectedTab: 2
        onCloseRequested: root.closeRequested()
    }
}
