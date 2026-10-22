import QtQuick
import "OperatorData.js" as Data
import "OperatorRuneData.js" as Rune

OperatorSentryRfidForm {
    id:root
    property var telemetry:null
    property var projectionItems:[]
    property int clientID:0
    property bool previewOnly:false
    property bool connected:false
    property bool displayAllowed:true
    property double displayNow:Date.now()
    readonly property var record:Rune.rfid(projectionItems,clientID,displayNow,previewOnly)
    readonly property bool preparation:Data.state(telemetry,"gameStatus","current_stage")==="fresh"
        && [0,1,2,3].includes(telemetry?.gameStatus?.current_stage)
    recognized:record?.recognized??false
    visible:displayAllowed && connected && preparation && record!==null
    Accessible.name:recognized?"哨兵已识别RFID":"哨兵未识别RFID"
    onProjectionItemsChanged:displayNow=Date.now()
    Timer {interval:250;repeat:true;running:root.displayAllowed && root.connected && root.projectionItems.length>0;onTriggered:root.displayNow=Date.now()}
}
