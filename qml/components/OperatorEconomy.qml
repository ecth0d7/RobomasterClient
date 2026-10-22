import QtQuick
import "OperatorData.js" as Data
import "OperatorFortressData.js" as FortressData

// 将贴图实现留在普通组件中，表单只暴露可编辑的区域和数据属性。
Item {
    id: root
    property string economyText: "—"
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property var progressScale: null
    readonly property string economyState: Data.state(telemetry,"globalLogistics","remaining_economy")
    readonly property bool economyAvailable: economyState !== "missing"
        && Number.isSafeInteger(telemetry?.globalLogistics?.remaining_economy)
    readonly property bool displayable: economyAvailable || FortressData.occupation(telemetry,clientID,false) !== null
        || FortressData.occupation(telemetry,clientID,true) !== null
    // 原经济区190＋两侧各70；无占领数据也保留这个边界，不能挤动机器人组。
    width: 330
    height: 58
    Image {
        x:70;y:0;width:190;height:58
        visible: root.economyAvailable
        source: "../resources/player/top_mid/BattleVolumn_Bg.png"
        fillMode: Image.Stretch
        mipmap: true
        opacity: 0.78
    }
    OperatorText {
        x: 84
        y: 17
        width: 60
        height: 23
        text: root.economyText + (root.economyState === "stale" ? "旧" : "")
        visible: root.economyAvailable
        numeric: true
        size: 16
        minimumSize: 8.5
        fontSizeMode:Text.Fit;minimumPixelSize:9
        color:root.economyState === "fresh" ? Theme.text : Theme.muted
        horizontalAlignment: Text.AlignHCenter
    }
    Canvas {
        // 手册只显示己方经济；右格是对方经济不可见，不是假造加密状态。
        x:201;y:18;width:28;height:22
        visible:root.economyAvailable
        Accessible.role:Accessible.StaticText
        Accessible.name:"对方经济不公开"
        onPaint: {
            const c=getContext("2d");c.reset();
            c.beginPath();c.moveTo(2,11);c.bezierCurveTo(8,1,20,1,26,11);
            c.bezierCurveTo(20,21,8,21,2,11);c.closePath();
            c.strokeStyle=Theme.blue;c.lineWidth=2;c.stroke();
            c.beginPath();c.arc(14,11,4,0,Math.PI*2);c.fillStyle=Theme.blue;c.fill();
            c.beginPath();c.moveTo(5,2);c.lineTo(23,20);c.strokeStyle=Theme.red;c.lineWidth=3;c.stroke();
        }
    }
    Image {
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 32
        height: 32
        visible:root.economyAvailable
        source: "../resources/player/panel/ic_gold_2x.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }
    OperatorFortress { x:0;y:0;telemetry:root.telemetry;clientID:root.clientID;previewOnly:root.previewOnly;progressScale:root.progressScale }
    OperatorFortress { x:parent.width-width;y:0;blue:true;telemetry:root.telemetry;clientID:root.clientID;previewOnly:root.previewOnly;progressScale:root.progressScale }
}
