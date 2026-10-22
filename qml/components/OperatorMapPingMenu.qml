import QtQuick
import QtQuick.Controls

Popup {
    id: root
    objectName: "mapPingMenu"
    parent: Overlay.overlay
    width: 132
    height: 224
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    readonly property var choiceItems: choices
    property int heldMode: 0
    onClosed: heldMode=0
    function openAt(surface, px, py) {
        if (!parent || !surface) return;
        const point = surface.mapToItem(parent, px, py);
        x = Math.max(8, Math.min(parent.width - width - 8, point.x - 12));
        y = Math.max(8, Math.min(parent.height - height - 8, point.y - height / 2));
        heldMode = 0;
        open();
    }
    function trackHeld(surface, px, py) {
        if (!opened) return;
        const p=surface.mapToItem(contentItem,px,py),dx=p.x-12,dy=p.y-112;
        const radius=Math.hypot(dx,dy),angle=Math.atan2(dy,dx)*180/Math.PI;
        heldMode=radius>=40 && radius<=124 && Math.abs(angle)<=72 ? (angle < -24 ? 1 : angle > 24 ? 3 : 2) : 0;
    }
    function finishHeld() {
        const mode=opened ? heldMode : 0;
        heldMode=0;
        close();
        return mode;
    }
    background: Canvas {
        onPaint: {
            const c=getContext("2d");c.reset();
            c.beginPath();c.arc(12,112,108,-72*Math.PI/180,72*Math.PI/180);
            c.arc(12,112,22,72*Math.PI/180,-72*Math.PI/180,true);c.closePath();
            c.fillStyle="#cc122525";c.fill();c.strokeStyle=Theme.hudBorder;c.lineWidth=1;c.stroke();
            for(const angle of [-24,24]) {
                const rad=angle*Math.PI/180;
                c.beginPath();c.moveTo(12+25*Math.cos(rad),112+25*Math.sin(rad));
                c.lineTo(12+105*Math.cos(rad),112+105*Math.sin(rad));c.stroke();
            }
        }
    }
    contentItem: Item {
        Repeater {
            id: choices
            model: [{mode:1,title:"进攻",icon:"attack",angle:-48}, {mode:2,title:"防守",icon:"defend",angle:0}, {mode:3,title:"警戒",icon:"warning",angle:48}]
            Button {
                id: choice
                required property var modelData
                objectName: "mapPingChoice" + modelData.mode
                x:12+76*Math.cos(modelData.angle*Math.PI/180)-width/2
                y:112+76*Math.sin(modelData.angle*Math.PI/180)-height/2
                width: 54; height: 54
                padding: 2
                Accessible.name: modelData.title + "，长按地图后滑至此处松开"
                background: Rectangle {
                    radius:27
                    color:choice.hovered || choice.activeFocus || root.heldMode===choice.modelData.mode ? Theme.hudHover : "#50122525"
                    border.color:choice.hovered || choice.activeFocus || root.heldMode===choice.modelData.mode ? Theme.green : "transparent"
                }
                contentItem: Column {
                    spacing: 0
                    Image { anchors.horizontalCenter: parent.horizontalCenter; width: 28; height: 28; source: "../resources/icons/map/" + choice.modelData.icon + ".svg" }
                    OperatorText { width: parent.width; height: 20; text: choice.modelData.title; size: 12; horizontalAlignment: Text.AlignHCenter }
                }
            }
        }
        OperatorText {x:0;y:100;width:25;height:24;text:"×";size:18;color:Theme.muted;horizontalAlignment:Text.AlignHCenter}
        MouseArea {x:0;y:92;width:31;height:40;cursorShape:Qt.PointingHandCursor;onClicked:root.close();Accessible.name:"取消地图标注"}
    }
}
