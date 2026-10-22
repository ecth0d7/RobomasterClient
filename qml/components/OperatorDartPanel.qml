import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "OperatorData.js" as Data
import "UiFormat.js" as Format
import "OperatorDartData.js" as Dart

OperatorRoleCard {
    id: root
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool actionsAvailable: false
    property string hostReason: ""
    property bool operatorAuthorized: false
    property var operationPolicy: ({})
    property var displayProjection: null
    property double displayNow:Date.now()
    readonly property var localDisplay:Dart.view(displayProjection,clientID,displayNow,previewOnly)
    readonly property bool openingsAvailable:localDisplay===null || localDisplay.remaining_openings>0
    readonly property bool localOpenAllowed:openingsAvailable && (localDisplay===null || localDisplay.cooldown_remaining_seconds===0)
    readonly property bool localLaunchAllowed:localDisplay===null || localDisplay.gate===2 && !localDisplay.detection_moving
    readonly property bool localGateMatches:localDisplay!==null && localDisplay.gate===gateValue && localDisplay.target_id===targetID
    readonly property string closedMessage:!localGateMatches || gateValue!==0 ? ""
        : localDisplay.cooldown_remaining_seconds>0 ? "飞镖发射站冷却中 "+localDisplay.cooldown_remaining_seconds+"秒"
        : localDisplay.remaining_openings===0 && localDisplay.next_opening_remaining_seconds!==null ? localDisplay.next_opening_remaining_seconds+"秒后可再次开启闸门"
        : localDisplay.remaining_openings===0 ? "飞镖闸门开启次数已达上限" : ""
    property string pendingAction: ""
    property int selectedTarget: 1
    property string feedback: ""
    property bool confirming: false
    readonly property string gateState: Data.state(telemetry, "dartTarget", "open")
    readonly property string targetState: Data.state(telemetry, "dartTarget", "target_id")
    readonly property var gateValue: telemetry?.dartTarget?.open
    readonly property var targetID: telemetry?.dartTarget?.target_id
    readonly property string outpostState: Data.state(telemetry, "globalUnit", "enemy_outpost_health")
    readonly property bool baseTargetsAllowed: outpostState === "fresh" && telemetry?.globalUnit?.enemy_outpost_health === 0
    readonly property var availableTargets: baseTargetsAllowed ? [2, 3, 4, 5] : [1]
    readonly property var targetLabels: ({1: "前哨站", 2: "基地固定目标", 3: "基地随机固定目标", 4: "基地随机移动目标", 5: "基地末端移动目标"})
    readonly property bool knownGate: gateState === "fresh" && [0, 1, 2].includes(gateValue)
    readonly property bool knownTarget: targetState === "fresh" && Number.isInteger(targetID) && targetID >= 1 && targetID <= 5
    readonly property bool qualified: Format.validLogin(clientID) && actionsAvailable && operatorAuthorized
        && (localDisplay===null || localDisplay.operations_allowed)
    readonly property bool targetConflict: knownTarget && outpostState === "fresh" && !availableTargets.includes(targetID)
    readonly property bool canTarget: qualified && knownGate && gateValue === 0 && openingsAvailable && (availableTargets.length > 1 || !availableTargets.includes(targetID)) && operationPolicy?.target === true
    readonly property bool canOpen: qualified && knownGate && gateValue === 0 && knownTarget && !targetConflict && localOpenAllowed && operationPolicy?.open === true
    readonly property bool canClose: qualified && knownGate && gateValue === 2 && operationPolicy?.close === true
    readonly property bool canLaunch: qualified && knownGate && gateValue === 2 && knownTarget && !targetConflict && localLaunchAllowed && operationPolicy?.launch === true
    readonly property bool pendingAllowed: allowed(pendingAction)
    readonly property bool shortcutsAllowed: visible
    readonly property string blockedReason: !Format.validLogin(clientID) ? "未选择合法选手端身份" : !actionsAvailable ? hostReason || "生产飞镖控制入口未接通" : !operatorAuthorized ? "云台手权限未确认" : !knownGate ? "闸门状态旧 / 缺失 / 未识别" : !knownTarget ? "当前目标旧 / 缺失 / 未识别" : targetConflict ? "目标与前哨状态冲突 · 待核对" : gateValue === 0 && operationPolicy?.open !== true ? "开闸资格未允许 · 次数 / 冷却待核对" : ""
    signal targetSwitchIntent
    signal openIntent
    signal closeIntent
    signal launchIntent
    signal dartIntent(var fields)
    readonly property bool online: Data.state(telemetry,"robotStatic","connection_state") === "fresh"
        && telemetry?.robotStatic?.connection_state === 1
    readonly property real baseHeight: confirming ? 310 : knownGate && gateValue === 1 ? 290
        : knownGate && gateValue === 2 ? 310 : closedMessage.length>0 ? 265 : 230
    title: online ? "飞镖在线" : "飞镖离线"
    accent: online ? Theme.actionGreen : Theme.red
    width: 384
    height: baseHeight
    contentMargin: 14
    headerCenterY: 19
    titleHeight: 28
    titleSize: 16
    titleAlignment: Text.AlignHCenter
    bodyTop: 50
    stateVisible: false
    dividerVisible: false
    closeButton: false
    headingBand: false
    surfaceColor: Theme.hudSurface
    outlineColor: "transparent"
    onDisplayProjectionChanged:displayNow=Date.now()
    Timer {interval:250;repeat:true;running:root.visible && root.displayProjection!==null;onTriggered:root.displayNow=Date.now()}
    onVisibleChanged: { if (!visible) clearSelection(); else syncTargetDraft(); }
    onTargetIDChanged: if (!pendingAction.length) syncTargetDraft()
    onTargetStateChanged: if (!pendingAction.length) syncTargetDraft()
    onAvailableTargetsChanged: {
        if (pendingAction === "target" && !availableTargets.includes(selectedTarget)) clearSelection();
        if (!pendingAction.length) syncTargetDraft();
    }
    onClientIDChanged: { clearSelection(); feedback = ""; selectedTarget = 1; }
    onPendingAllowedChanged: if (!pendingAllowed) clearSelection()
    function clearSelection() { pendingAction = ""; confirming = false; }
    function syncTargetDraft() { selectedTarget = knownTarget && availableTargets.includes(targetID) ? targetID : availableTargets[0]; }
    function allowed(action) {
        if (action === "target") return canTarget && availableTargets.includes(selectedTarget);
        if (action === "open") return canOpen;
        if (action === "close") return canClose;
        return action === "launch" && canLaunch;
    }
    function selectAction(action) { if (visible && allowed(action)) { pendingAction = action; confirming = true; feedback = ""; } }
    function selectTarget(target) {
        if (canTarget && availableTargets.includes(target) && target !== targetID) {
            selectedTarget = target;
            targetSwitchIntent();
            dartIntent({target_id: target});
        }
    }
    function launch() {
        if (!visible || !canLaunch || confirming) return;
        launchIntent();
        dartIntent({launch_confirm: true});
    }
    function nextTarget() {
        if (!canTarget) return;
        const index = availableTargets.indexOf(pendingAction === "target" ? selectedTarget : targetID);
        selectTarget(availableTargets[(index + 1) % availableTargets.length]);
    }
    function confirm() {
        if (!visible || !pendingAllowed || !confirming) return;
        const action = pendingAction, target = selectedTarget;
        clearSelection();
        // Protobuf字段存在性有意义；不为其他动作补默认open=false或launch_confirm=false。
        if (action === "target") { targetSwitchIntent(); dartIntent({target_id: target}); }
        else if (action === "open") { openIntent(); dartIntent({open: true}); }
        else if (action === "close") { closeIntent(); dartIntent({open: false}); }
        else if (action === "launch") { launchIntent(); dartIntent({launch_confirm: true}); }
    }
    OperatorActionShortcut { scopeItem: root; actionId: "dartTarget"; available: root.shortcutsAllowed; onActivated: root.nextTarget() }
    OperatorActionShortcut { scopeItem: root; actionId: "dartOpen"; available: root.shortcutsAllowed; onActivated: root.selectAction("open") }
    OperatorActionShortcut { scopeItem: root; actionId: "dartLaunch"; available: root.shortcutsAllowed; onActivated: root.launch() }
    OperatorActionShortcut { scopeItem: root; actionId: "dartConfirm"; available: root.shortcutsAllowed && root.confirming; onActivated: root.confirm() }
    OperatorActionShortcut { scopeItem: root; actionId: "dartCancel"; available: root.shortcutsAllowed && root.confirming; onActivated: root.clearSelection() }

    OperatorActionShortcut { scopeItem:root;actionId:"dartClose";available:root.shortcutsAllowed;onActivated:root.selectAction("close") }

    Button {
        id: targetSwitch
        objectName:"dartTargetSwitch"
        width: parent.width; height: 34
        enabled: root.canTarget && !root.confirming
        Accessible.name: "切换飞镖目标"
        background: Item {}
        contentItem: Item {
            Image {
                x: 4; width: 32; height: 32
                source: "../resources/player/silo/silo_border_normal.png"
                mipmap: true
                OperatorText { anchors.fill: parent; text: root.shortcutLabel("dartTarget"); size: 14; horizontalAlignment: Text.AlignHCenter; opacity: targetSwitch.enabled ? 1 : 0.3 }
            }
            OperatorText { x: 48; width: parent.width - 48; height: 32; text: "切换目标"; size: 13; opacity: targetSwitch.enabled ? 1 : 0.3 }
        }
        onClicked: root.nextTarget()
    }
    Item {
        y: 48; width: parent.width; height: 34
        Image { x: 7; y: 6; width: 16; height: 16; source: "../resources/player/silo/silo_icon_aim.png"; fillMode: Image.PreserveAspectFit; mipmap: true }
        OperatorText { x: 48; width: 65; height: parent.height; text: "当前目标"; size: 12 }
        Rectangle {
            x: 119; y: 2; width: parent.width - 123; height: 30
            color: "transparent"; border.width: 1; border.color: "#bce7e3"
            OperatorText {
                anchors.fill: parent; anchors.margins: 3
                text: root.targetState === "missing" ? "—" : root.targetLabels[root.targetID] ?? "未识别目标"
                size: 12; fontSizeMode: Text.Fit; minimumPixelSize: 9.5/Math.max(.1,hudScale)
                horizontalAlignment: Text.AlignHCenter
                color: root.targetState === "fresh" ? "#bce7e3" : Theme.muted
            }
        }
    }
    Rectangle { y: 89; x: -root.contentMargin; width: root.width; height: 1; color: "#353535" }
    Button {
        id: gateAction
        objectName:"dartGateAction"
        y: 109; width: parent.width; height: 34
        visible: root.gateValue !== 1
        enabled: !root.confirming && (root.gateValue === 2 ? root.canLaunch : root.canOpen)
        Accessible.name: root.gateValue === 2 ? "发射飞镖" : "开启飞镖闸门"
        background: Item {}
        contentItem: Item {
            Image {
                x: 4; width: 32; height: 32
                source: "../resources/player/silo/silo_border_normal.png"
                mipmap: true
                OperatorText { anchors.fill: parent; text: root.shortcutLabel(root.gateValue === 2 ? "dartLaunch" : "dartOpen"); size: 14; horizontalAlignment: Text.AlignHCenter; opacity: gateAction.enabled ? 1 : 0.3 }
            }
            OperatorText { x: 48; width: parent.width - 48; height: 32; text: root.gateValue === 2 ? "发射飞镖" : "开启飞镖闸门"; size: 13; opacity: gateAction.enabled ? 1 : 0.3 }
        }
        onClicked: root.gateValue === 2 ? root.launch() : root.selectAction("open")
    }
    Column {
        x: 55; y: 155; spacing: 12; width: parent.width - 70
        visible: root.confirming
        Repeater {
            model: [true, false]
            Button {
                id: confirmation
                required property bool modelData
                objectName:modelData ? "dartConfirm" : "dartCancel"
                width: parent.width; height: 32
                enabled: !modelData || root.pendingAllowed
                Accessible.name: modelData ? "确定飞镖操作" : "取消飞镖操作"
                background: Item {}
                contentItem: Item {
                    BorderImage {
                        width: 32; height: 32
                        source: "../resources/player/silo/silo_border_" + (confirmation.modelData ? "green" : "red") + ".png"
                        border { left: 8; right: 8; top: 8; bottom: 8 }
                        OperatorText { anchors.fill: parent; text: root.shortcutLabel(confirmation.modelData ? "dartConfirm" : "dartCancel"); color: confirmation.modelData ? Theme.actionGreen : Theme.red; size: 14; horizontalAlignment: Text.AlignHCenter }
                    }
                    OperatorText { x: 44; width: parent.width - 44; height: 32; text: confirmation.modelData ? "确定" : "取消"; color: confirmation.modelData ? Theme.actionGreen : Theme.red; size: 13 }
                }
                onClicked: modelData ? root.confirm() : root.clearSelection()
            }
        }
    }
    Column {
        y: 109; width: parent.width; spacing: 8
        visible: root.knownGate && root.gateValue === 1
        OperatorText { width: parent.width; height: 28; text: "闸门运行中"; size: 14; horizontalAlignment: Text.AlignHCenter }
        OperatorText { width: parent.width; height: 24; text:root.localGateMatches ? root.localDisplay.detection_moving ? "飞镖检测模块运行中…" : "飞镖检测模块停止运动" : "飞镖检测模块状态 —";size:12;horizontalAlignment:Text.AlignHCenter }
        BusyIndicator {
            id:gateBusy
            anchors.horizontalCenter:parent.horizontalCenter;width:48;height:48;running:parent.visible
            Accessible.name:"正在开启飞镖闸门"
            // 系统样式的黑色转圈在图传上不可读，使用手册的浅色细环。
            contentItem:Shape {
                width:48;height:48;antialiasing:true
                ShapePath {fillColor:"transparent";strokeWidth:3;strokeColor:"#559fb8b5";capStyle:ShapePath.RoundCap
                    PathAngleArc {centerX:24;centerY:24;radiusX:18;radiusY:18;startAngle:0;sweepAngle:360}}
                ShapePath {fillColor:"transparent";strokeWidth:3;strokeColor:"#bce7e3";capStyle:ShapePath.RoundCap
                    PathAngleArc {centerX:24;centerY:24;radiusX:18;radiusY:18;startAngle:-90;sweepAngle:150}}
                RotationAnimator on rotation {from:0;to:360;duration:1100;loops:Animation.Infinite;running:gateBusy.running && !Theme.reducedMotion}
            }
        }
    }
    Column {
        y:155;width:parent.width;spacing:8
        visible:!root.confirming && root.knownGate && root.gateValue===2
        OperatorText {width:parent.width;height:26;text:root.localGateMatches ? root.localDisplay.detection_moving ? "飞镖检测模块运行中…" : "飞镖检测模块停止运动" : "飞镖检测模块状态 —";size:12;horizontalAlignment:Text.AlignHCenter}
        OperatorText {width:parent.width;height:54;text:root.localGateMatches ? root.localDisplay.close_remaining_seconds+" 秒" : "—";size:30;numeric:true;horizontalAlignment:Text.AlignHCenter;Accessible.name:"闸门关闭倒计时 "+text}
    }
    OperatorText {objectName:"dartClosedState";y:158;width:parent.width;height:46;visible:!root.confirming && root.closedMessage.length>0;text:root.closedMessage;size:13;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;color:root.localDisplay?.remaining_openings===0 && root.localDisplay?.next_opening_remaining_seconds===null && root.localDisplay?.cooldown_remaining_seconds===0 ? Theme.red : Theme.text}
    HoverHandler { id: panelHover }
    ToolTip.visible: panelHover.hovered && (root.blockedReason.length > 0 || root.feedback.length > 0 || root.localDisplay!==null)
    ToolTip.delay: 600
    ToolTip.text: [root.feedback || root.blockedReason,root.localDisplay!==null ? "本地扩展数据 · 剩余开闸次数 "+root.localDisplay.remaining_openings+"；计时由同一服务器提供，暂停冻结。" : ""].filter(text=>text.length>0).join("\n")
}
