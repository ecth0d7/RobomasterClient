import QtQuick
import QtQuick.Controls
import "OperatorModuleData.js" as Modules

Item {
    id: root
    objectName: "bottomStatusHud"
    property var telemetry: null
    property int clientID: 0
    property bool connectedToPlayer: false
    property bool previewOnly: false
    property var displayData: null
    property string displaySessionId: ""
    property bool displayProjectionConnected: false
    property bool detailVisible: false
    property double drawingNow: Date.now()
    readonly property var display: Modules.view(telemetry,clientID,connectedToPlayer,displayData,
        displaySessionId,displayProjectionConnected,drawingNow,previewOnly)
    readonly property bool displayable: display.displayable
    signal detailsRequested(int page)
    function refreshClock() {drawingNow=Math.max(drawingNow,Date.now());}
    onDisplayDataChanged: Qt.callLater(root.refreshClock)
    onVisibleChanged: if (visible) Qt.callLater(root.refreshClock)
    onDetailVisibleChanged: if (detailVisible) Qt.callLater(root.refreshClock)
    Timer {interval:250;repeat:true;running:(root.visible || root.detailVisible) && root.displayData !== null;onTriggered:root.refreshClock()}
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "查看模块与底部状态来源。"+display.hud.filter(f => f.present).map(f => f.caption+"，"+f.text).join("；")
    Keys.onReturnPressed: event => {event.accepted=true;root.detailsRequested(root.display.native.present > 0 ? 1 : 2);}
    Keys.onSpacePressed: event => {event.accepted=true;root.detailsRequested(root.display.native.present > 0 ? 1 : 2);}
    width:490
    height:52
    Repeater {
        model:Modules.slots
        Item {
            id:cell
            required property var modelData
            required property int index
            readonly property var reading:root.display.hud[index]
            readonly property bool live:reading.state === "fresh" && reading.tone !== "muted"
            visible:true
            // 不能用Grid隐藏子项后自动补位：缺失字段只空出自己的位置。
            x:index%5*((root.width-48)/5+12)
            y:Math.floor(index/5)*26
            width:(root.width-48)/5
            height:24
            Image {
                width:18;height:18
                visible:cell.live
                source:"../resources/official/"+(cell.reading.tone === "green" ? "模块在线.png" : cell.reading.tone === "warning" ? "模块不规范.png" : "模块离线.png")
                fillMode:Image.PreserveAspectFit
                mipmap:true
                Accessible.ignored:true
            }
            OperatorSlantedFill {
                width:18;height:18
                visible:!cell.live
                source:"../resources/official/模块在线.png"
                sourceClipRect:Qt.rect(0,0,37,37)
                fraction:1;slantWidth:0;tint:Theme.muted;opacity:0.48
            }
            OperatorText {
                x:22;width:parent.width-22;height:18;size:11;clip:true
                minimumSize:0;fontSizeMode:Text.Fit;minimumPixelSize:8
                text:cell.modelData.label
                color:cell.reading.warning ? Theme.warning : cell.live ? Theme.text : Theme.muted
            }
            MouseArea {
                anchors.fill:parent;cursorShape:Qt.PointingHandCursor
                onClicked:root.detailsRequested(cell.reading.state !== "conflict"
                    && (cell.reading.native_module === true || cell.reading.native_summary === true) ? 1 : 2)
            }
            HoverHandler {id:hover}
            OperatorDataToolTip {visible:hover.hovered;text:(cell.reading && cell.reading.description) ? cell.reading.description : ""}
        }
    }
    OperatorOutline {visible:root.activeFocus;color:Theme.green;emphasized:true}
}
