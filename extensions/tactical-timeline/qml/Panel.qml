import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../qml/components" as Client
import "JournalData.js" as Data
Column {
    id:root;objectName:"tacticalTimelinePanel";spacing:10
    property var host:null
    property var season:null
    property double now:Date.now()
    property string feedback:""
    readonly property var view:host?.view??({})
    onViewChanged:now=Date.now()
    onVisibleChanged:if(visible)now=Date.now()
    readonly property var records:Data.records(view,now)
    Timer {interval:250;repeat:true;running:root.visible;onTriggered:root.now=Date.now()}
    Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:13;color:Client.Theme.muted;text:"先启动态势协调器。人工标注仅短时有效5秒，历史保留60秒／最多128条；不会参与机器人位置融合，不代表已确认敌人。地图上的“人”符号与视觉／雷达分开。"}
    Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:13;color:Client.Theme.warning;text:(root.host?.view?.journal?.status??"时间线尚未启动；先加载完整态势配置并启用协调器")+" · 接纳记录 "+root.records.length+" · 拒绝 "+(root.host?.view?.journal?.rejected??0)}
    Client.OperatorConfigTextField {id:label;objectName:"tacticalMarkText";width:parent.width;maximumLength:64;placeholderText:"人工信息，最多64字，例如：观察东侧通道";Accessible.name:"战术标注内容"}
    RowLayout {
        width:parent.width;spacing:12
        Client.OperatorConfigComboBox {id:intent;objectName:"tacticalMarkIntent";Layout.fillWidth:true;model:["观察","防守","集合"];Accessible.name:"标注用途"}
        CheckBox {id:includePoint;objectName:"tacticalMarkPoint";text:"含坐标";palette.windowText:Client.Theme.text}
    }
    RowLayout {width:parent.width;visible:includePoint.checked
        Client.OperatorConfigTextField {id:pointX;objectName:"tacticalMarkX";Layout.fillWidth:true;placeholderText:"X / 米";Accessible.name:"标注X坐标"}
        Client.OperatorConfigTextField {id:pointY;objectName:"tacticalMarkY";Layout.fillWidth:true;placeholderText:"Y / 米";Accessible.name:"标注Y坐标"}
    }
    Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:12;text:"坐标系："+(root.host?.view?.frame_id??"未提供")+"；无对应底图时只列文字。共享接收端须启用时间线，授权operator.tactical／sensor／本参考系及fusion用途。";color:Client.Theme.muted}
    CheckBox {id:share;objectName:"tacticalMarkShare";text:"发送给已配置并授权的队友（默认不发送）";palette.windowText:Client.Theme.text}
    Client.OperatorButton {
        objectName:"tacticalMarkSubmit";text:"提交人工标注";laboratory:true;primary:true
        enabled:root.host?.active===true && root.host?.view?.journal?.enabled===true && label.text.trim().length>0
        onClicked:{
            const p=includePoint.checked?[Number(pointX.text),Number(pointY.text)]:[];
            const height=root.host.view.frame_id==="field.2027"?16:15;
            if(includePoint.checked && (!pointX.text.trim() || !pointY.text.trim() || !p.every(Number.isFinite) || p[0]<0 || p[0]>28 || p[1]<0 || p[1]>height)){root.feedback="请填写当前参考系内的有效米制坐标";return;}
            root.feedback=root.host.addTacticalMark(label.text,["observe","defend","rally"][intent.currentIndex],p,share.checked)
                ?"已提交本机队列；以下接纳记录才证明已记录，网络提交不代表队友收到。":"未提交，请检查服务状态";
        }
    }
    Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:12;text:root.feedback;color:Client.Theme.muted}
    Repeater {model:root.records.length
        Rectangle {required property int index;readonly property var modelData:root.records[index];width:root.width;height:Math.max(82,entry.implicitHeight+24);color:Client.Theme.hudSolid
            Rectangle {width:3;height:parent.height;color:modelData.live?Client.Theme.accent:Client.Theme.hudBorder}
            Column {id:entry;x:14;y:12;width:parent.width-28;spacing:6
                Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:14;text:"人工 / "+({observe:"观察",defend:"防守",rally:"集合"})[modelData.intent]+" · "+modelData.text;color:modelData.live?Client.Theme.text:Client.Theme.muted}
                Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:12;text:modelData.state+" · "+modelData.origin+" · "+new Date(modelData.stamp_ms).toISOString()+" · "+modelData.frame_id+(modelData.point?" / "+modelData.point.join(", ")+"m":" / 无坐标");color:Client.Theme.muted}
            }
        }
    }
}
