import QtQuick
import QtQuick.Window
import "OperatorData.js" as Data
import "OperatorExchangeData.js" as Exchange
import "OperatorShortcutRegistry.js" as Shortcuts
import "OperatorFocus.js" as PanelFocus

FocusScope {
    id:root
    objectName:"exchangePanel"
    property var telemetry:null
    property int clientID:0
    property bool previewOnly:false
    property bool actionsAvailable:false
    property string hostReason:""
    property var commandPolicy:({})
    property var projectionItems:[]
    property double drawingNow:Date.now()
    property int selectedTab:0
    property string supplyKind:"buy17"
    property string selectedKind:""
    property string quantity17:"10"
    property string quantity42:"1"
    property string feedback:""
    property bool confirming:false
    property string quotedSignature:""
    property string lastIssuedKind:""
    property var lastIssuedFields:null
    property double lastIssuedAt:0
    property double lastIssuedBaseline:0
    property string pendingKind:""
    property bool submissionRejected:false
    readonly property bool operatorPanelKeyboardBoundary:true
    readonly property var shortcutPreferences:Window.window?.ui?.shortcutPreferencesObject ?? null
    readonly property var localView:Exchange.localView(projectionItems,clientID,drawingNow,previewOnly)
    readonly property var selectedItem:Exchange.item(selectedKind)
    readonly property var selectedPolicy:commandPolicy?.[selectedKind] ?? ({})
    readonly property string selectedAmount:selectedKind==="buy17" ? quantity17 : quantity42
    readonly property var selectedQuote:Exchange.quote(localView,selectedItem,selectedPolicy,selectedAmount)
    readonly property var selectedFields:Exchange.fields(selectedItem,selectedPolicy,selectedAmount)
    readonly property string selectionReason:reason(selectedKind)
    readonly property string currentSignature:selectedQuote ? JSON.stringify(selectedQuote) : ""
    readonly property bool canConfirm:confirming && !selectionReason.length && selectedQuote!==null && currentSignature===quotedSignature
    readonly property bool shortcutsAllowed:visible && Window.window?.active===true
    readonly property real supplyQuantity:supplyReason.length ? 0 : Number(supplyKind==="buy17" ? quantity17 : quantity42)
    readonly property var supplyOffer:localView?.offers?.[supplyKind]
    readonly property var coins:Data.state(telemetry,"globalLogistics","remaining_economy")==="fresh" ? telemetry.globalLogistics.remaining_economy : null
    readonly property var affordable:supplyOffer && Number.isInteger(coins) ? Math.min(supplyOffer.maxQuantity,Math.floor(coins/supplyOffer.unitCost/(supplyKind==="buy17" ? 10 : 1))*(supplyKind==="buy17" ? 10 : 1)) : null
    readonly property string supplyReason:reason(supplyKind,false)
    readonly property bool canQuoteSupply:supplyReason.length===0 && Number.isInteger(supplyQuantity) && supplyQuantity>0 && affordable!==null && supplyQuantity<=affordable
    readonly property string ammoText:Data.text(telemetry,"robotDynamic","remaining_ammo")
    readonly property var serverResult:{
        const r=localView?.result;
        if(!pendingKind || !r || r.sequence<=lastIssuedBaseline || r.kind!==pendingKind || r.receivedAtMs<lastIssuedAt || r.cmdType!==lastIssuedFields?.cmd_type || (r.param ?? null)!==(lastIssuedFields?.param ?? null))return null;
        return r;
    }
    readonly property bool remoteResponseVisible:selectedTab===0 && (pendingKind.length>0 || submissionRejected)
    readonly property bool responseFailed:submissionRejected || serverResult?.status==="rejected"
    readonly property string responseText:submissionRejected ? feedback || "请求未被接受" : serverResult?.status==="rejected" ? serverResult.error
        : serverResult?.status==="pending" ? "购买成功，"+serverResult.remainingSeconds+"s 后生效" : serverResult?.status==="applied" ? "兑换已生效" : "等待购买结果"
    readonly property string confirmationText:{
        if(!selectedQuote)return "兑换条件已变化";
        const description=selectedKind==="remoteHeal" ? "恢复60%血量" : "兑换"+selectedQuote.amount+"发"+(["remote42","buy42"].includes(selectedKind) ? "42" : "17")+"mm弹丸";
        return selectedTab===0 ? "是否消耗 "+selectedQuote.cost+" 金币\n"+description+"？" : "此次兑换将消耗 "+selectedQuote.cost+" 金币，\n请确认是否兑换";
    }
    signal exchangeIntent(string kind)
    signal commonIntent(var fields)
    signal closeRequested
    width:selectedTab===1 ? supply.width : remote.width
    height:selectedTab===1 ? supply.height : remote.height
    onProjectionItemsChanged:drawingNow=Date.now()
    onVisibleChanged:{
        cancelSelection();drawingNow=Date.now();
        if(visible){if(serverResult?.status!=="pending")pendingKind="";submissionRejected=false;forceActiveFocus();}
    }
    onClientIDChanged:resetContext()
    onActionsAvailableChanged:if(!actionsAvailable)resetContext()
    onSelectedTabChanged:cancelSelection()
    onSelectionReasonChanged:Qt.callLater(invalidateSelection)
    onCurrentSignatureChanged:Qt.callLater(invalidateSelection)
    Timer {interval:250;repeat:true;running:root.visible;onTriggered:root.drawingNow=Date.now()}
    function resetContext(){cancelSelection();pendingKind="";lastIssuedKind="";lastIssuedFields=null;feedback="";submissionRejected=false;}
    function shortcutLabel(kind){const id=kind==="remoteHeal" ? "exchange1" : kind==="remote17" ? "exchange2" : "exchange3";return shortcutPreferences ? shortcutPreferences.sequence(id) : Shortcuts.sequence(id,{});}
    function reason(kind,checkAmount=true){
        const entry=Exchange.item(kind);
        const base=Exchange.eligibility(telemetry,clientID,entry,commandPolicy?.[kind],actionsAvailable);
        const offer=localView?.offers?.[kind];
        // 补弹页先显示手册规定的机构/区域/经济原因；详情保留原生资格。
        if(entry?.tab===1 && offer && !offer.enabled)return offer.reason;
        if(base)return base;
        if(!offer)return "兑换报价／区域信息未提供";
        if(!offer.enabled)return offer.reason;
        const amount=kind==="buy17" ? quantity17 : quantity42;
        if(entry.tab===1 && !checkAmount)return "";
        const quote=Exchange.quote(localView,entry,commandPolicy?.[kind],amount);
        if(!quote)return "数量或参数映射未确认";
        if(coins===null || coins<quote.cost)return "金币不足，无法兑换";
        return "";
    }
    function cancelSelection(){confirming=false;selectedKind="";quotedSignature="";}
    function invalidateSelection(){if(confirming && (selectionReason.length || !currentSignature || currentSignature!==quotedSignature))cancelSelection();}
    function openRemote(){selectedTab=0;cancelSelection();}
    function openSupply(kind){
        selectedTab=1;supplyKind=kind;cancelSelection();pendingKind="";submissionRejected=false;
        if(kind==="buy17")quantity17="10";else quantity42="1";
    }
    function adjustQuantity(delta){
        if(confirming || supplyReason.length || affordable===null)return;
        const value=Math.max(0,Math.min(affordable,supplyQuantity+delta));
        if(supplyKind==="buy17")quantity17=String(value);else quantity42=String(value);
    }
    function select(kind){
        if(!visible || reason(kind).length)return;
        selectedKind=kind;
        const quote=Exchange.quote(localView,Exchange.item(kind),commandPolicy?.[kind],kind==="buy17" ? quantity17 : quantity42);
        if(!quote){cancelSelection();return;}
        quotedSignature=JSON.stringify(quote);confirming=true;submissionRejected=false;feedback="";
    }
    function chooseShortcut(index){if(selectedTab===0 && !confirming && !remoteResponseVisible)select(["remoteHeal","remote17","remote42"][index]);}
    function confirm(){
        if(!visible || !canConfirm)return;
        const kind=selectedKind,fields=selectedQuote.fields;
        lastIssuedKind=kind;lastIssuedFields=fields;lastIssuedAt=Date.now();lastIssuedBaseline=localView?.result?.sequence ?? 0;
        cancelSelection();exchangeIntent(kind);commonIntent(fields);
    }
    function recordSubmission(fields,accepted){
        if(!lastIssuedKind || fields.cmd_type!==lastIssuedFields?.cmd_type || (fields.param ?? null)!==(lastIssuedFields?.param ?? null))return;
        if(lastIssuedKind.startsWith("remote")){pendingKind=accepted ? lastIssuedKind : "";submissionRejected=!accepted;}
    }
    OperatorActionShortcut {scopeItem:root;actionId:"exchange1";available:root.shortcutsAllowed;onActivated:root.chooseShortcut(0)}
    OperatorActionShortcut {scopeItem:root;actionId:"exchange2";available:root.shortcutsAllowed;onActivated:root.chooseShortcut(1)}
    OperatorActionShortcut {scopeItem:root;actionId:"exchange3";available:root.shortcutsAllowed;onActivated:root.chooseShortcut(2)}
    OperatorActionShortcut {scopeItem:root;actionId:"exchangeConfirm";available:root.shortcutsAllowed && root.canConfirm;onActivated:root.confirm()}
    OperatorActionShortcut {scopeItem:root;actionId:"exchangeEnter";available:root.shortcutsAllowed && (root.canConfirm || root.selectedTab===1 && root.canQuoteSupply);onActivated:{if(root.confirming)root.confirm();else root.select(root.supplyKind);}}
    OperatorActionShortcut {scopeItem:root;actionId:"exchangeCancel";available:root.shortcutsAllowed && root.confirming;onActivated:root.cancelSelection()}
    Shortcut {sequence:"Tab";enabled:root.shortcutsAllowed;autoRepeat:false;onActivated:PanelFocus.move(root,root.Window.window.activeFocusItem,true)}
    Shortcut {sequence:"Shift+Tab";enabled:root.shortcutsAllowed;autoRepeat:false;onActivated:PanelFocus.move(root,root.Window.window.activeFocusItem,false)}
    Keys.onEscapePressed:event=>{if(root.confirming)root.cancelSelection();else root.closeRequested();event.accepted=true;}
    OperatorRemoteExchangeCard {id:remote;visible:root.selectedTab!==1;controller:root;width:implicitWidth;height:implicitHeight}
    OperatorSupplyCard {id:supply;visible:root.selectedTab===1;controller:root;width:implicitWidth;height:implicitHeight}
}
