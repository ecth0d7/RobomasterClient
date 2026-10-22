import QtQuick
import "OperatorData.js" as Data
import "OperatorSentryData.js" as Sentry

OperatorRoleCard {
    id: root
    property var telemetry: null
    property int clientID: 7
    property bool previewOnly: false
    property bool actionsAvailable: false
    property string hostReason: ""
    property var commandReasons: ({})
    property string feedback: ""
    property int page: 0
    property var projectionItems: []
    property bool supportMode:false
    property var supportProjection:null
    property bool localBusy:false
    property var selectedCost:null
    property double displayNow: Date.now()
    readonly property var localDisplay: supportMode?Sentry.supportView(supportProjection,clientID,displayNow,previewOnly,telemetry):Sentry.view(projectionItems,clientID,displayNow,previewOnly,telemetry)
    onProjectionItemsChanged: displayNow=Date.now()
    onSupportProjectionChanged:displayNow=Date.now()
    Timer {interval:250;repeat:true;running:root.visible;onTriggered:root.displayNow=Date.now()}
    property var selectedAction: null
    readonly property bool radarMode: clientID % 100 === 9 && !supportMode
    readonly property bool sentryMode: clientID % 100 === 7 || supportMode
    readonly property var sentry: telemetry?.sentryStatus ?? ({})
    readonly property string postureState: Data.state(telemetry, "sentryStatus", "posture_id")
    readonly property bool postureOld:[postureState,Data.state(telemetry,"sentryStatus","is_powered"),Data.state(telemetry,"sentryStatus","is_weakened")].includes("stale")
    readonly property string postureLabel:(Data.state(telemetry,"sentryStatus","is_powered")!=="missing" && sentry.is_powered?"强化":"")+(Sentry.postures[sentry.posture_id]??"未知姿态")+(Data.state(telemetry,"sentryStatus","is_weakened")!=="missing" && sentry.is_weakened?" · 效果下降":"")+([Data.state(telemetry,"sentryStatus","is_powered"),Data.state(telemetry,"sentryStatus","is_weakened")].includes("missing")?" · 强化/弱化未知":"")
    readonly property string radarState: Data.state(telemetry, "radar", "radar_single_robot_info")
    readonly property var radarRows: radarState === "missing" ? [] : Sentry.radarRows(telemetry, clientID)
    readonly property var activeCommands: Sentry.commands.filter(item => page === 0 ? item.posture !== undefined : item.posture === undefined)
    signal postureIntent(int commandID)
    signal controlIntent(int commandID)
    signal localIntent(var fields)
    signal mapRequested
    title: radarMode ? "雷达 · 官方位置 / 标识" : supportMode?"战术支援哨兵 · "+(clientID>100?107:7):"哨兵控制 · " + clientID
    iconSource: radarMode ? "" : "../resources/player/top_robots/" + (clientID > 100 ? "blue" : "red") + "_guard_avatar.png"
    accent: Theme.text
    stateHeight:28
    manageFocusTraversal:parent.objectName!=="operatorLargeMap"
    customIcon: radarMode
    stateText: root.headerText()
    width: 430; height: radarMode ? 430 : supportMode?770:700
    onVisibleChanged: { if (!visible) selectedAction = null; else displayNow=Date.now(); }
    onClientIDChanged: { selectedAction = null; feedback = ""; }
    function headerText() {
        let label="";
        if(radarMode)label="RadarInfoToClient · "+({fresh:"新鲜消息",stale:"旧消息",missing:"未收到 / 时效未公开"})[radarState];
        else if(!sentryMode)label="本机非哨兵 · 控制停用";
        else if(postureState==="missing")label="等待哨兵姿态";
        else {
            label=postureLabel+(postureOld?" · 旧数据":"");
            if(supportMode && !localDisplay)label=postureOld?label+" · 目标待核对":"收到姿态消息 · 目标待核对";
        }
        return label+(previewOnly?" · mock":"");
    }
    function reason(action) {
        if(!action)return "请选择操作";
        if (!sentryMode) return "此身份不请求哨兵动作";
        if(localBusy)return "正在等待上一次操作结果";
        if (!actionsAvailable) return hostReason || "生产哨兵控制入口未接通";
        if (!previewOnly && commandReasons[String(action.id)]) return commandReasons[String(action.id)];
        const offer=Sentry.actionOffer(action,localDisplay);
        if (offer && !offer.enabled) return offer.reason;
        if(supportMode)return localDisplay && offer?"":"等待己方哨兵状态";
        if (action.posture !== undefined && (postureState !== "fresh" || !Sentry.postures[sentry.posture_id] || Data.state(telemetry, "sentryStatus", "is_powered") !== "fresh" || Data.state(telemetry, "sentryStatus", "is_weakened") !== "fresh")) return "姿态 / 强化 / 弱化字段旧或缺失";
        if (action.revive && (Data.state(telemetry, "robotStatic", "alive_state") !== "fresh" || telemetry?.robotStatic?.alive_state !== 2)) return "尚未确认战亡状态";
        if (action.posture === undefined && Data.state(telemetry, "robotStatic", "alive_state") !== "fresh") return "存活字段旧或缺失";
        return "";
    }
    function select(action) {
        if(reason(action))return;
        if(action.local==="map_forward" && localDisplay?.map_offer?.active){localIntent({operation:"map_forward",enabled:false});selectedAction=null;return;}
        selectedAction=action;selectedCost=Sentry.actionOffer(action,localDisplay)?.cost??null;feedback="";
    }
    function confirm() {
        if (!selectedAction || reason(selectedAction)) return;
        if(supportMode && Sentry.actionOffer(selectedAction,localDisplay)?.cost!==selectedCost){selectedAction=null;feedback="费用已变化，请重新选择";return;}
        const action = selectedAction; selectedAction = null;
        if(action.local){localIntent(action.local==="ammo"?{operation:"ammo",quantity:action.quantity}:{operation:"map_forward",enabled:true});return;}
        if (action.posture !== undefined) postureIntent(action.id);
        controlIntent(action.id);
    }
    OperatorActionShortcut { scopeItem: root; actionId: "sentryConfirm"; available: root.visible && root.sentryMode && !!root.selectedAction && !root.reason(root.selectedAction); onActivated: root.confirm() }
    OperatorActionShortcut { scopeItem: root; actionId: "sentryCancel"; available: root.visible && !!root.selectedAction; onActivated: root.selectedAction = null }
    function chooseShortcut(index) { const item=activeCommands[index];if(item)select(item); }
    Repeater {
        model:["sentry1","sentry2","sentry3","sentry4","sentry5","sentry6"]
        Item {
            id: sentryRoute
            required property string modelData
            required property int index
            OperatorActionShortcut { scopeItem:root;actionId:sentryRoute.modelData;available:root.visible && root.sentryMode;onActivated:root.chooseShortcut(sentryRoute.index) }
        }
    }
    OperatorActionShortcut { scopeItem:root;actionId:"sentryPage";available:root.visible && root.sentryMode && root.parent.objectName!=="operatorLargeMap";onActivated:{root.page=1-root.page;root.selectedAction=null;} }
    OperatorRadarGlyph { x: 7; y: root.headerCenterY - 94 - height / 2; width: 18; height: 18; visible: root.radarMode }
    Item {
        anchors.fill: parent; visible: !root.radarMode
        OperatorText { width: parent.width; height: 26; text: root.supportMode ? root.localDisplay?({0:"自动哨兵",1:"半自动哨兵"})[root.localDisplay.control_mode]+" · 干预加收"+root.localDisplay.intervention_cost+"金币":"等待己方哨兵状态" : "控制  " + (Data.state(root.telemetry, "robotPerfSync", "sentry_control") === "missing" ? "—" : ({0: "自动", 1: "半自动"})[root.telemetry?.robotPerfSync?.sentry_control] ?? "未知") + (Data.state(root.telemetry, "robotPerfSync", "sentry_control") === "stale" ? " · 旧" : ""); size: 12 }

        Grid {
            y: 28; width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 6
            Repeater {
                model: root.supportMode?Sentry.supportActions:Sentry.commands.filter(item=>item.posture===undefined)
                OperatorSentryAction {
                    required property var modelData
                    objectName:"sentryAction"+modelData.id
                    width:(parent.width-8)/2;height:64
                    caption:modelData.title;detail:Sentry.detail(modelData,root.localDisplay)
                    glyphSource:modelData.local==="map_forward"?"../resources/icons/map/sentry-forward.svg":""
                    showCoin:!!Sentry.actionOffer(modelData,root.localDisplay) && !(modelData.revive && root.reason(modelData)) && !activated
                    enabled:!root.reason(modelData);blockedReason:root.reason(modelData)
                    selected:root.selectedAction?.id===modelData.id
                    activated:modelData.local==="map_forward" && root.localDisplay?.map_offer?.active===true
                    onClicked:root.select(modelData)
                }
            }
        }
        OperatorText {y:root.supportMode?308:238;width:parent.width;height:26;text:"切换姿态";size:12;color:Theme.muted}
        Grid {
            y:root.supportMode?336:266;width:parent.width;columns:2;columnSpacing:8;rowSpacing:6
            Repeater {
                model:Sentry.commands.filter(item=>item.posture!==undefined)
                OperatorSentryAction {
                    required property var modelData
                    objectName:"sentryAction"+modelData.id
                    width:(parent.width-8)/2;height:66
                    caption:modelData.title;detail:Sentry.detail(modelData,root.localDisplay)
                    showCoin:!!Sentry.actionOffer(modelData,root.localDisplay)
                    glyphAsset:"buff_guard_"+modelData.icon
                    iconColor:!modelData.powered?Theme.text:({1:"#f4a15b",2:"#62e5cf",3:"#b1ed65"})[modelData.posture]
                    enabled:!root.reason(modelData);blockedReason:root.reason(modelData)
                    selected:root.selectedAction?.id===modelData.id
                    activated:(!root.supportMode || root.localDisplay!==null) && root.postureState==="fresh" && root.sentry.posture_id===modelData.posture
                        && Data.state(root.telemetry,"sentryStatus","is_powered")==="fresh" && root.sentry.is_powered===modelData.powered
                    weakened:!modelData.powered && root.localDisplay?.normal_seconds[modelData.posture-1]===0
                    onClicked:root.select(modelData)
                }
            }
        }
        OperatorText { y: parent.height - 90; width: parent.width; height: 26; text: (root.previewOnly ? "mock · " : "") + (root.supportMode?Sentry.supportResult(root.localDisplay,root.telemetry):Sentry.result(root.telemetry)); size: 10; color: Data.state(root.telemetry, "sentryCtrlResult", "result_code") === "fresh" && root.telemetry?.sentryCtrlResult?.result_code !== 0 ? Theme.warning : Theme.muted }
        OperatorText { y: parent.height - 62; width: parent.width; height: 26; text: root.selectedAction ? root.reason(root.selectedAction) || (root.selectedAction.paid ? "待确认："+root.selectedAction.title+" · "+Sentry.detail(root.selectedAction,root.localDisplay) : "待确认：" + root.selectedAction.title) : root.feedback || root.reason(root.activeCommands[0]) || (root.previewOnly ? "离线样例 · 选择不发送，确认仅记录" : "选择操作 · "+root.shortcutLabel("sentryConfirm")+" 确认 / "+root.shortcutLabel("sentryCancel")+" 取消"); size: 10; color: root.selectedAction?.paid ? Theme.warning : Theme.muted }
        Row { y: parent.height - 36; width: parent.width; spacing: 10
            OperatorButton { width: (parent.width - 10) / 2; height: 36; text: root.previewOnly ? "确认记录 · 预览" : "确认请求"; primary: true; enabled: !!root.selectedAction && !root.reason(root.selectedAction); onClicked: root.confirm() }
            OperatorButton { width: (parent.width - 10) / 2; height: 36; text: "取消选择"; enabled: !!root.selectedAction; onClicked: root.selectedAction = null }
        }
    }
    Item {
        anchors.fill: parent; visible: root.radarMode
        OperatorText { width: parent.width; height: 26; text: "收到 " + root.radarRows.length + " / 12项 · 接收时间未公开"; size: 11; color: Theme.muted }
        OperatorScrollableColumn {
            y: 34; width: parent.width; height: parent.height - y - 76; entrySpacing: 8
            Repeater { model: root.radarRows
                Item {
                    required property var modelData
                    width: parent.width; height: 58
                    OperatorOutline { color: Theme.line }
                    OperatorText { x: 8; y: 3; width: parent.width - 16; height: 26; text: modelData.side + " " + modelData.robotId + " · " + modelData.position; size: 11; color: root.radarState === "stale" || modelData.offline ? Theme.warning : modelData.robotId > 100 ? Theme.blue : Theme.red }
                    OperatorText { x: 8; y: 29; width: parent.width - 16; height: 24; text: modelData.mark + (root.radarState === "stale" ? " · 旧消息" : ""); size: 10; color: Theme.muted }
                }
            }
            OperatorText { width: parent.width; height: 60; visible: !root.radarRows.length; text: "没有官方雷达位置列表；不以0坐标补充目标，不借用哨兵状态。"; wrapMode: Text.WordWrap; size: 11; color: Theme.muted }
        }
        OperatorText { y: parent.height - 66; width: parent.width; height: 30; text: "官方cm转m显示 · 顺序按协议 · 定位离线仅参考"; size: 10; color: Theme.muted }
        OperatorButton { y: parent.height - 30; width: parent.width; height: 30; text: "查看地图 / 原始来源"; onClicked: root.mapRequested() }
    }
}
