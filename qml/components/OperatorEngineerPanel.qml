import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "OperatorData.js" as Data
import "OperatorAssemblyData.js" as Assembly

OperatorRoleCard {
    id: root
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool actionsAvailable: false
    property string hostReason: ""
    property int selectedDifficulty: 1
    property bool selecting: true
    property var assemblyDifficulty: null
    property bool assemblyContextValid: false
    property var assemblyContext: null
    property bool canConfirmDifficulty: false
    property int contextDraftDifficulty: 1
    property string outcome: ""
    property int outcomeCode:-1
    property double outcomeObservedAt:0
    property bool outcomeVerified: false
    property string outcomeSource: ""
    property string outcomeReason: ""
    property string feedback: ""
    property bool cancelArmed: false
    property int submittedDifficulty: 0
    property double submittedAt: 0
    property bool observedAssembly: false
    property bool exiting: false
    property double cancelSubmittedAt:0
    property double drawingNow: Date.now()
    property var projectionItems:[]
    property bool bufferNotice:false
    property double bufferObservedAt:0
    readonly property var localAssembly:Assembly.view(projectionItems,clientID,currentRound,drawingNow,previewOnly)
    readonly property bool localCoherent:Assembly.coherent(localAssembly,core)
    readonly property bool temporaryActive:localCoherent && localAssembly.temporary_active
    readonly property bool outsideAssemblyZone:localCoherent && localAssembly.active && !localAssembly.in_assembly_zone
    readonly property bool exitBuffer:localCoherent && localAssembly.exit_buffer_remaining_seconds>0 || bufferNotice
    readonly property bool failedWaiting:localCoherent && localAssembly.awaiting_exit
        || outcomeVerified && outcomeCode===5 && freshCore && [2,3].includes(core.basic_state)
            && Data.state(telemetry,"techCore","remain_time_all")==="fresh" && core.remain_time_all>0
            && core.remain_time_all<=45
    readonly property bool cooperationReady:displayDifficulty!==4 || localCoherent && localAssembly.paired && localAssembly.opponent.steps.every(v=>v===1)
    property int observedRound: 0
    property alias difficultyMenuObject:contextMenu
    readonly property var core: telemetry?.techCore ?? ({})
    readonly property int currentRound: telemetry?.gameStatus?.current_round ?? 0
    readonly property string coreState: Data.state(telemetry,"techCore","basic_state")
    readonly property string difficultyState: Data.state(telemetry,"techCore","maximum_difficulty_level")
    readonly property bool engineer: clientID % 100 === 2
    readonly property bool assemblyInputAvailable:Data.state(telemetry,"gameStatus","current_stage")==="fresh"
        && telemetry.gameStatus.current_stage===4 && Data.state(telemetry,"gameStatus","is_paused")==="fresh"
        && telemetry.gameStatus.is_paused===false
    readonly property bool robotReady: Data.state(telemetry,"robotStatic","alive_state")==="fresh" && telemetry.robotStatic.alive_state===1
        && Data.state(telemetry,"robotStatic","connection_state")==="fresh" && telemetry.robotStatic.connection_state===1
        && Data.state(telemetry,"robotStatic","field_state")==="fresh" && telemetry.robotStatic.field_state===0
    readonly property bool currentKnown: assemblyContextValid && Number.isInteger(assemblyDifficulty) && assemblyDifficulty>=1 && assemblyDifficulty<=4
        && (localAssembly===null || !(localAssembly.active || localAssembly.awaiting_exit) || localAssembly.difficulty===assemblyDifficulty)
    readonly property bool freshCore: coreState === "fresh" && [1,2,3].includes(core.basic_state)
    readonly property bool hasOutcome: !temporaryActive && outcomeVerified && ["success","failed"].includes(outcome)
    readonly property int displayDifficulty: currentKnown ? assemblyDifficulty : localCoherent && (localAssembly.active || temporaryActive || localAssembly.awaiting_exit) ? localAssembly.difficulty
        : outcomeVerified && outcomeCode===5 ? 4
        : hasOutcome && localAssembly?.last_outcome===outcomeCode && localAssembly.run_id>0 ? localAssembly.difficulty
        : localAssembly?.active && localAssembly.difficulty!==submittedDifficulty ? 0 : submittedDifficulty
    readonly property var stepFields: ["putin_state","move_state","rotate_state"].slice(0,displayDifficulty>=3 ? 3 : displayDifficulty===2 ? 2 : 1)
    readonly property bool stepsComplete: displayDifficulty>=1 && stepFields.every(key => Data.state(telemetry,"techCore",key)==="fresh" && core[key]===1)
    readonly property bool canStart: engineer && actionsAvailable && assemblyInputAvailable && robotReady && freshCore && core.basic_state===1 && difficultyState==="fresh"
        && selectedDifficulty>=1 && selectedDifficulty<=core.maximum_difficulty_level && selectedDifficulty<=4 && !hasOutcome
        && (localAssembly===null || localAssembly.operations_allowed)
    readonly property bool canConfirm: engineer && actionsAvailable && assemblyInputAvailable && robotReady && currentKnown && freshCore && core.basic_state===3 && stepsComplete && cooperationReady && !hasOutcome && !failedWaiting
        && (localAssembly===null || localAssembly.operations_allowed)
    readonly property bool canCancel: engineer && actionsAvailable && assemblyInputAvailable && currentKnown && freshCore && (!hasOutcome || failedWaiting)
    readonly property bool failureExitAvailable:failedWaiting && engineer && actionsAvailable && freshCore
        && Data.state(telemetry,"gameStatus","current_stage")==="fresh" && telemetry.gameStatus.current_stage===4
        && Data.state(telemetry,"gameStatus","is_paused")==="fresh" && telemetry.gameStatus.is_paused===false
        && Data.state(telemetry,"techCore","remain_time_all")==="fresh" && (currentKnown || canConfirmDifficulty)
    readonly property bool confirmSelectedContext: !currentKnown && canConfirmDifficulty && submittedDifficulty>=1 && submittedDifficulty<=4
        && submittedAt>0 && drawingNow-submittedAt<60000
        && (localAssembly===null || !localAssembly.active || localAssembly.difficulty===submittedDifficulty)
    readonly property bool confirmationAvailable: canConfirm || engineer && actionsAvailable && assemblyInputAvailable && robotReady && freshCore && core.basic_state===3
        && stepsComplete && cooperationReady && !hasOutcome && !failedWaiting && confirmSelectedContext && (localAssembly===null || localAssembly.operations_allowed)
    readonly property string blockedReason:unavailableReason()
    signal difficultyIntent(int difficulty)
    signal confirmationIntent
    signal cancellationIntent
    signal assemblyIntent(int operation,int difficulty)
    signal assemblyContextIntent(int difficulty)
    signal attentionRequested
    title: selecting ? "装配难度选择" : ""
    titleSize: 19
    titleHeight: selecting ? 30 : 0
    headerCenterY: 26
    stateVisible: false
    dividerVisible: false
    closeButton: false
    contentMargin: selecting ? 18 : 0
    bodyTop: selecting ? 90 : 0
    surfaceColor: Theme.hudSurface
    outlineColor: "#9b7b8a85"
    width: selecting ? 640 : displayDifficulty===4 || exitBuffer || failedWaiting ? 390 : 340
    height: selecting ? 430 : failedWaiting || (displayDifficulty===4 || exitBuffer) && !hasOutcome ? 300 : 200
    onClientIDChanged: { submittedDifficulty=0;submittedAt=0;outcomeVerified=false;bufferNotice=false;exiting=false;observedRound=currentRound; }
    onCurrentRoundChanged: {
        if(observedRound>0 && currentRound!==observedRound) { submittedDifficulty=0;submittedAt=0;outcomeVerified=false;bufferNotice=false; }
        observedRound=currentRound;
    }
    onActionsAvailableChanged: if(!actionsAvailable) { submittedDifficulty=0;submittedAt=0; }
    onCoreStateChanged:if(coreState!=="fresh")bufferNotice=false
    onProjectionItemsChanged:drawingNow=Date.now()
    onLocalAssemblyChanged:Qt.callLater(discardMismatchedSubmission)
    onTemporaryActiveChanged:if(temporaryActive){outcomeVerified=false;selecting=false;attentionRequested();}
    Timer { interval:500;repeat:true;running:root.visible && (root.submittedAt>0 || root.projectionItems.length>0);onTriggered:root.drawingNow=Date.now() }
    onCoreChanged: Qt.callLater(syncPanel)
    onVisibleChanged: { if(visible)syncPanel();else cancelArmed=false; }
    function syncPanel() {
        if(!visible || !freshCore || hasOutcome)return;
        if(temporaryActive || exitBuffer){selecting=false;return;}
        if(core.basic_state!==1) { observedAssembly=true;selecting=false; }
        else if(observedAssembly) { observedAssembly=false;selecting=true; }
    }
    function fieldText(key,labels) {
        const state=Data.state(telemetry,"techCore",key);
        if(state==="missing")return "—";
        return labels ? labels[core[key]] ?? "—" : Number.isFinite(core[key]) ? String(core[key]) : "—";
    }
    function unavailableReason() {
        if(!engineer)return "本机非工程机器人";
        if(!actionsAvailable)return hostReason;
        if(!assemblyInputAvailable)return Data.state(telemetry,"gameStatus","is_paused")==="fresh" && telemetry.gameStatus.is_paused===true?"装配操作已暂停":"比赛状态未确认或当前阶段无法装配";
        if(!freshCore)return "装配状态尚未确认";
        if(!robotReady)return "机器人需存活、在线并已上场";
        if(selecting) {
            if(difficultyState!=="fresh")return "可选难度尚未确认";
            if(localAssembly && !localAssembly.in_assembly_zone)return "未占领装配区，无法装配";
            if(localAssembly && !localAssembly.operations_allowed)return "当前状态无法装配";
            if(selectedDifficulty>core.maximum_difficulty_level)return "该难度暂不可用，请选择其他等级";
        } else if(!currentKnown && !confirmSelectedContext && !hasOutcome)return "请在底栏确认本轮实际难度";
        return "";
    }
    function discardMismatchedSubmission() {
        if(localCoherent && exiting && localAssembly.active && localAssembly.source.produced_at_ms>cancelSubmittedAt)exiting=false;
        if(localCoherent && bufferNotice && localAssembly.source.produced_at_ms>bufferObservedAt && localAssembly.exit_buffer_remaining_seconds===0) {
            bufferNotice=false;syncPanel();
        }
        if(!localCoherent || !(localAssembly.active || localAssembly.awaiting_exit))return;
        if(submittedDifficulty>0 && submittedDifficulty!==localAssembly.difficulty){submittedDifficulty=0;submittedAt=0;}
        if(localAssembly.awaiting_exit) {
            if(exiting)return;
            if(!outcomeVerified || outcomeCode!==5 || outcomeObservedAt===0)outcomeObservedAt=localAssembly.source.produced_at_ms;
            outcomeVerified=true;outcome="failed";outcomeCode=5;outcomeReason="装配间隔已超时";
            outcomeSource="同一服务器实际装配结果";selecting=false;observedAssembly=true;return;
        }
        if(hasOutcome && localAssembly.source.produced_at_ms>outcomeObservedAt){outcomeVerified=false;outcomeCode=-1;exiting=false;selecting=false;observedAssembly=true;}
    }
    function assemblyInstruction(moving) {
        if(outsideAssemblyZone)return "请返回装配区 · "+localAssembly.outside_remaining_seconds+"s";
        if(moving)return "运动中…";
        if(!stepsComplete)return "请装配";
        if(displayDifficulty!==4 || cooperationReady)return "确认装配前请移出装配机构";
        if(!localCoherent)return "对方装配步骤待确认";
        return localAssembly.paired?"等待对方完成装配":"等待对方四级装配";
    }
    function outcomeHeading() {
        if(outcome==="success")return ["","一级","二级","三级","四级"][displayDifficulty]+"科技核心装配成功";
        return outcomeCode===7?outcomeReason:"装配失败";
    }
    function chooseDifficulty(level) {
        if(engineer && difficultyState==="fresh" && level>=1 && level<=core.maximum_difficulty_level && level<=4)selectedDifficulty=level;
    }
    function recordSubmission(fields,accepted) {
        if(!accepted)return;
        if(fields.operation===0) {
            submittedDifficulty=fields.difficulty;submittedAt=Date.now();drawingNow=submittedAt;observedAssembly=false;exiting=false;outcomeVerified=false;
            outcomeCode=-1;
        } else if(fields.operation===1)submittedDifficulty=fields.difficulty;
        else if(fields.operation===2) { exiting=true;cancelSubmittedAt=Date.now();selecting=true;outcomeVerified=false;outcomeCode=-1; }
    }
    function request(operation) {
        if(!visible || !(operation===0 ? canStart : operation===1 ? canConfirm : operation===2 && canCancel && cancelArmed))return;
        const difficulty=operation===0 ? selectedDifficulty : assemblyDifficulty;
        cancelArmed=false;
        if(operation===0)difficultyIntent(difficulty);else if(operation===1)confirmationIntent();else cancellationIntent();
        assemblyIntent(operation,difficulty);
    }
    function confirmContext() {
        if(!visible || selecting || !canConfirmDifficulty || hasOutcome && !failedWaiting)return;
        assemblyContextIntent(contextDraftDifficulty);
    }
    function requestCurrent(operation) {
        if(temporaryActive && operation===2){closeRequested();return;}
        if(failedWaiting && operation===2 && !failureExitAvailable)return;
        if(hasOutcome && operation===2 && !failedWaiting) { outcomeVerified=false;selecting=true;return; }
        if(!assemblyInputAvailable)return;
        if(!currentKnown) {
            if(!confirmSelectedContext || Date.now()-submittedAt>=60000) { contextMenu.open();return; }
            // Y/L在此明确确认刚才选择并提交的参数；真实位姿回传和原生守卫仍分别检查。
            contextDraftDifficulty=submittedDifficulty;
            assemblyContextIntent(contextDraftDifficulty);
            Qt.callLater(function(){ if(root.currentKnown && root.assemblyDifficulty===root.submittedDifficulty) { root.cancelArmed=operation===2;root.request(operation); } });
            return;
        }
        cancelArmed=operation===2;request(operation);
    }
    Connections {
        target: root.telemetry
        ignoreUnknownSignals: true
        function onEventReceived(id,param) {
            if(root.engineer && id===14) {
                root.bufferNotice=true;root.bufferObservedAt=Date.now();root.outcomeVerified=false;
                root.observedAssembly=true;root.selecting=false;root.attentionRequested();return;
            }
            const code=String(param).trim();
            if(!root.engineer || id!==15 || !/^[0-8]$/.test(code) || root.exiting && code==="6")return;
            root.bufferNotice=false;
            root.exiting=false;
            root.outcomeVerified=true;root.outcome=code==="0" ? "success" : "failed";
            root.outcomeCode=Number(code);
            root.outcomeObservedAt=Date.now();
            root.outcomeReason=({1:"能量单元脱离装配机构",2:"装配超时",3:"离开装配区过久",4:"机器人阵亡",5:"装配间隔已超时",6:"主动退出",7:"未能检测到有效能量单元",8:"强制退出缓冲到期"})[Number(code)] ?? "";
            root.outcomeSource="Event(15)";root.selecting=false;
        }
    }
    OperatorActionShortcut { scopeItem:root;actionId:"engineerStart";available:root.visible && root.selecting;onActivated:root.request(0) }
    OperatorActionShortcut { scopeItem:root;actionId:"engineerConfirm";available:root.visible && !root.selecting && root.confirmationAvailable;onActivated:root.requestCurrent(1) }
    OperatorActionShortcut { scopeItem:root;actionId:"engineerPage";available:root.visible && !root.selecting;onActivated:root.requestCurrent(2) }
    OperatorActionShortcut { scopeItem:root;actionId:"engineerContext";available:root.visible && !root.selecting && root.canConfirmDifficulty;onActivated:root.confirmContext() }
    Repeater {
        model:[1,2,3,4]
        Item {
            id:difficultyRoute
            required property int modelData
            OperatorActionShortcut { scopeItem:root;actionId:"engineerDifficulty"+difficultyRoute.modelData;available:root.visible && root.selecting;onActivated:root.chooseDifficulty(difficultyRoute.modelData) }
        }
    }
    Item {
        anchors.fill: parent;visible:root.selecting
        Row {y:-45;width:parent.width;spacing:12
            OperatorText {width:(parent.width-12)/2;height:28;text:"当前等级上限  "+(root.localAssembly?root.localAssembly.robot_level_cap:"—");size:12;color:Theme.muted}
            OperatorText {width:(parent.width-12)/2;height:28;text:"当前金币收益  "+(root.localAssembly?root.localAssembly.coins_per_ten_seconds+"金币/10s":"—");size:12;color:Theme.muted;horizontalAlignment:Text.AlignRight}
        }
        Row {
            y: 2; width: parent.width; height: 28
            Repeater {
                model:[{title:"按键",width:44},{title:"等级",width:80},{title:"首次装配奖励",width:220},{title:"非首次装配奖励",width:260}]
                OperatorText { required property var modelData; width:modelData.width;height:28;text:modelData.title;size:12;horizontalAlignment:Text.AlignHCenter;color:Theme.muted }
            }
        }
        Rectangle { x:0;y:0;width:parent.width;height:246;color:"transparent";border.color:"#5c696d68";border.width:1 }
        Column {
            y:36;width:parent.width;spacing:2
            Repeater {
                model:[1,2,3,4]
                Button {
                    id: difficulty
                    required property int modelData
                    objectName:"engineerChoice"+modelData
                    width:parent.width;height:45
                    padding:0
                    enabled:root.engineer && root.difficultyState==="fresh" && modelData<=root.core.maximum_difficulty_level
                    onClicked:root.chooseDifficulty(modelData)
                    Accessible.name:["","一级","二级","三级","四级"][modelData]+"装配难度"
                    background: Rectangle { color:root.selectedDifficulty===difficulty.modelData ? "#39385c60" : "transparent";border.width:root.selectedDifficulty===difficulty.modelData ? 1 : 0;border.color:"#7662b1b8" }
                    contentItem: Item {
                        Image {x:12;y:10;width:25;height:25;source:"../resources/player/silo/silo_border_normal.png";fillMode:Image.PreserveAspectFit;OperatorText {anchors.fill:parent;text:difficulty.modelData;size:11;horizontalAlignment:Text.AlignHCenter} }
                        OperatorText {x:44;width:80;height:parent.height;text:["","一级","二级","三级","四级"][difficulty.modelData];size:13;horizontalAlignment:Text.AlignHCenter}
                        OperatorText {x:106;width:18;height:parent.height;text:"✓";size:14;color:"#50c8d5";visible:root.selectedDifficulty===difficulty.modelData}
                        Image {x:144;y:13;width:19;height:19;source:"../resources/player/panel/ic_gold_2x.png";fillMode:Image.PreserveAspectFit;mipmap:true}
                        OperatorText {x:174;width:154;height:parent.height;text:root.localAssembly?root.localAssembly.first_rates[difficulty.modelData-1]+"金币/10s":"—";size:12;color:root.localAssembly?.first_completed[difficulty.modelData-1]?Theme.muted:Theme.text}
                        Image {x:364;y:13;width:19;height:19;source:"../resources/player/panel/ic_gold_2x.png";fillMode:Image.PreserveAspectFit;mipmap:true}
                        OperatorText {x:394;width:parent.width-x-16;height:parent.height;text:difficulty.modelData===4 ? root.localAssembly?.level4_used ? "本局已完成" : root.localAssembly?.level4_cooldown_seconds>0 ? "冷却 "+root.localAssembly.level4_cooldown_seconds+"s" : "仅限每局一次" : root.localAssembly?root.localAssembly.repeat_rates[difficulty.modelData-1]+"金币/10s":"—";size:12;color:root.localAssembly?.first_completed[difficulty.modelData-1]?Theme.text:Theme.muted}
                        opacity:difficulty.enabled ? 1 : .35
                    }
                }
            }
        }
        OperatorText {objectName:"engineerUnavailableReason";y:248;width:parent.width;height:24;text:root.blockedReason;visible:text.length>0;size:12;horizontalAlignment:Text.AlignHCenter;color:Theme.warning}
        Button {
            x:(parent.width-width)/2;y:parent.height-48;width:180;height:32
            objectName:"engineerStart"
            enabled:root.canStart;text:"确定 [Enter]"
            background:Rectangle {color:parent.down ? "#38646b" : "#22383c";radius:2;border.color:parent.enabled ? "#67b8c4" : "#536363";border.width:1}
            contentItem:OperatorText {text:parent.text;size:15;horizontalAlignment:Text.AlignHCenter;color:parent.enabled ? "#c8f6fa" : Theme.muted}
            onClicked:root.request(0)
        }
    }
    Item {
        anchors.fill:parent;visible:!root.selecting
        readonly property bool moving:root.freshCore && root.core.basic_state===2
        readonly property bool timed:root.failedWaiting || (root.displayDifficulty===4 || root.exitBuffer) && !root.hasOutcome
        Rectangle { x:8;y:parent.timed ? 47 : 8;width:parent.width-16;height:parent.height-y-42;color:"#33202421";radius:4;border.color:"#7b93968f";border.width:1 }
        Item {
            id:assemblyTimer
            objectName:"engineerAssemblyTimer"
            x:(parent.width-width)/2;y:4;width:190;height:36;visible:parent.timed
            readonly property bool known:root.exitBuffer ? root.localCoherent : Data.state(root.telemetry,"techCore","remain_time_all")==="fresh"
                && Number.isInteger(root.core.remain_time_all) && root.core.remain_time_all>=0 && root.core.remain_time_all<=45
            readonly property int remaining:root.exitBuffer ? root.localAssembly?.exit_buffer_remaining_seconds??0 : root.core.remain_time_all??0
            readonly property int total:root.exitBuffer?15:45
            Shape {
                width:36;height:36;antialiasing:true
                ShapePath {fillColor:"transparent";strokeColor:"#58697d76";strokeWidth:1.5
                    PathAngleArc {centerX:18;centerY:18;radiusX:16;radiusY:16;startAngle:0;sweepAngle:360}}
                ShapePath {fillColor:"transparent";strokeColor:root.exitBuffer?Theme.red:"#bce7e3";strokeWidth:1.5
                    PathAngleArc {centerX:18;centerY:18;radiusX:16;radiusY:16;startAngle:-90;sweepAngle:assemblyTimer.known?360*assemblyTimer.remaining/assemblyTimer.total:0}}
            }
            OperatorText {width:36;height:36;text:assemblyTimer.known?assemblyTimer.remaining+"s":"—";size:11;numeric:true;horizontalAlignment:Text.AlignHCenter}
            OperatorText {x:48;width:142;height:36;text:root.exitBuffer?"强制退出缓冲":"装配倒计时";size:13;color:root.exitBuffer?Theme.red:Theme.text}
        }
        OperatorText {
            x:18;y:root.failedWaiting?65:root.hasOutcome ? root.outcome==="success" ? 72 : 40 : parent.timed ? 65 : 32;width:parent.width-36;height:34
            text:root.failedWaiting?"装配间隔已超时":root.temporaryActive ? "已临时激活" : root.hasOutcome ? root.outcomeHeading()
                : root.assemblyInstruction(parent.moving)
            size:root.hasOutcome ? 20 : 17;fontSizeMode:Text.Fit;minimumPixelSize:Math.max(12,9.5/Math.max(.1,hudScale));horizontalAlignment:Text.AlignHCenter
            color:root.temporaryActive?Theme.red:root.hasOutcome ? root.outcome==="success" ? Theme.actionGreen : Theme.red : root.outsideAssemblyZone?Theme.warning:Theme.text
        }
        OperatorText {
            x:18;y:root.failedWaiting?106:parent.timed ? 112 : 78;width:parent.width-36;height:root.failedWaiting?60:30;visible:root.temporaryActive || parent.moving || root.hasOutcome && root.outcome==="failed"
            text:root.failedWaiting?"请移出装配机构后确认退出\n装配倒计时归零将强制复位":root.temporaryActive?"请避让科技核心后退出激活状态":root.hasOutcome ? root.outcomeCode===7?"装配失败":root.outcomeReason : "前往装配点";size:15;horizontalAlignment:Text.AlignHCenter;color:root.temporaryActive || root.hasOutcome ? Theme.red : Theme.text
        }
        Row {
            y:parent.timed ? 112 : 80;anchors.horizontalCenter:parent.horizontalCenter;spacing:16
            visible:!parent.moving && !root.hasOutcome && !root.temporaryActive && root.displayDifficulty>=1 && root.displayDifficulty!==4
            Repeater {
                model:root.stepFields
                OperatorText {
                    required property string modelData
                    width:68;height:26;text:({putin_state:"放入",move_state:"平移",rotate_state:"旋转"})[modelData]
                    size:16;horizontalAlignment:Text.AlignHCenter
                    color:Data.state(root.telemetry,"techCore",modelData)==="fresh" && root.core[modelData]===1 ? Theme.actionGreen : Theme.muted
                }
            }
        }
        Column {
            y:112;anchors.horizontalCenter:parent.horizontalCenter;spacing:4
            visible:root.displayDifficulty===4 && !parent.moving && !root.hasOutcome && !root.temporaryActive
            Repeater {
                model:["red","blue"]
                Row {
                    id:teamSteps
                    required property string modelData
                    readonly property bool selfRow:(root.clientID>100)===(modelData==="blue")
                    spacing:8;height:26
                    OperatorText {width:46;height:26;text:teamSteps.modelData==="red"?"红方":"蓝方";size:14;color:teamSteps.modelData==="red"?Theme.red:Theme.blue}
                    Repeater {
                        model:["putin_state","move_state","rotate_state"]
                        OperatorText {
                            required property string modelData
                            required property int index
                            objectName:"engineerStep"+teamSteps.modelData+"_"+modelData
                            readonly property bool known:teamSteps.selfRow?Data.state(root.telemetry,"techCore",modelData)==="fresh"
                                :root.localCoherent && root.localAssembly.paired
                            readonly property bool complete:known && (teamSteps.selfRow?root.core[modelData]===1:root.localAssembly.opponent.steps[index]===1)
                            width:68;height:26;text:known?({putin_state:"放入",move_state:"平移",rotate_state:"旋转"})[modelData]:"—"
                            size:16;horizontalAlignment:Text.AlignHCenter;color:complete?Theme.actionGreen:Theme.muted
                        }
                    }
                }
            }
        }
        Button {
            x:(parent.width-width)/2;y:parent.timed ? 190 : 116;width:90;height:30
            objectName:"engineerConfirm"
            padding:0
            visible:!parent.moving && !root.hasOutcome && !root.temporaryActive;enabled:root.confirmationAvailable
            background:Item {}
            contentItem:Item {
                Image {width:26;height:26;source:parent.parent.enabled ? "../resources/player/silo/silo_border_green.png" : "../resources/player/silo/silo_border_normal.png";fillMode:Image.PreserveAspectFit;OperatorText {anchors.fill:parent;text:"Y";size:13;horizontalAlignment:Text.AlignHCenter;color:root.confirmationAvailable ? Theme.actionGreen : Theme.muted}}
                OperatorText {x:36;width:54;height:26;text:"确定";size:14;color:root.confirmationAvailable ? Theme.actionGreen : Theme.muted}
            }
            onClicked:root.requestCurrent(1)
        }
        Button {
            objectName:"engineerTemporaryAcknowledge"
            x:(parent.width-width)/2;y:190;width:90;height:30;visible:root.temporaryActive
            padding:0
            Accessible.name:"确认临时激活提示"
            background:Item{}
            contentItem:Item {
                Image {y:2;width:26;height:26;source:"../resources/player/silo/silo_border_normal.png";fillMode:Image.PreserveAspectFit
                    OperatorText {anchors.fill:parent;text:"L";size:13;color:Theme.red;horizontalAlignment:Text.AlignHCenter}}
                OperatorText {x:36;width:54;height:30;text:"确定";size:14;color:Theme.red}
            }
            onClicked:root.closeRequested()
        }
        Button {
            objectName:"engineerFailureExit"
            x:(parent.width-width)/2;y:root.failedWaiting?190:116;width:90;height:30;visible:root.failedWaiting || root.hasOutcome && root.outcome==="failed"
            padding:0;enabled:root.failedWaiting?root.failureExitAvailable:true
            Accessible.name:root.failedWaiting?"退出失败的四级装配":"确认装配失败结果"
            background:Item{}
            contentItem:Item {
                Image {y:2;width:26;height:26;source:"../resources/player/silo/silo_border_normal.png";fillMode:Image.PreserveAspectFit
                    OperatorText {anchors.fill:parent;text:"L";size:13;color:root.failedWaiting && !root.failureExitAvailable?Theme.muted:Theme.red;horizontalAlignment:Text.AlignHCenter}}
                OperatorText {x:36;width:54;height:30;text:"确定";size:14;color:root.failedWaiting && !root.failureExitAvailable?Theme.muted:Theme.red}
            }
            onClicked:root.requestCurrent(2)
        }
        OperatorText {y:226;width:parent.width;height:26;visible:root.exitBuffer && !root.hasOutcome
            text:root.temporaryActive?"请在缓冲结束前避让科技核心":"请在缓冲结束前取消或完成装配";size:12;horizontalAlignment:Text.AlignHCenter;color:Theme.red}
        OperatorText {y:226;width:parent.width;height:26;visible:!root.exitBuffer && !root.hasOutcome && parent.timed && !parent.moving && root.localCoherent && root.localAssembly.waiting_for_partner
            text:"步骤协作剩余 "+root.fieldText("remain_time_step")+"s";size:13;horizontalAlignment:Text.AlignHCenter;color:Theme.warning}
        Rectangle {
            x:8;y:parent.height-42;width:parent.width-16;height:34;color:"#66434843";radius:3;border.color:"#647b827b";border.width:1
            Button {
                width:parent.width*.42;height:parent.height
                background:Item {}
                contentItem:OperatorText {text:root.displayDifficulty>0 ? ["","一级","二级","三级","四级"][root.displayDifficulty]+"难度" : "本轮难度待确认";size:12;horizontalAlignment:Text.AlignHCenter}
                onClicked:if(root.canConfirmDifficulty)contextMenu.open()
            }
            OperatorText {x:parent.width*.42;width:parent.width*.58;height:parent.height;text:root.temporaryActive?"按‘L’确认提示":root.failedWaiting?"按‘L’退出装配":root.hasOutcome ? "按‘L’返回" : "按‘L’退出装配";size:12;horizontalAlignment:Text.AlignHCenter}
        }
    }
    Menu {
        id:contextMenu
        objectName:"engineerContextMenu"
        title:"确认本轮实际难度"
        Repeater {
            model:[1,2,3,4]
            MenuItem {required property int modelData;text:modelData+"级";enabled:root.canConfirmDifficulty;onTriggered:{root.contextDraftDifficulty=modelData;root.confirmContext();}}
        }
    }
    HoverHandler {id:statusHover}
    ToolTip.visible:statusHover.hovered && (root.feedback.length>0 || root.blockedReason.length>0)
    ToolTip.delay:700
    ToolTip.text:root.feedback || root.blockedReason
}
