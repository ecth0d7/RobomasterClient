import QtQuick
import QtQuick.Layouts
import "../../../qml/components" as Client
import "HealthData.js" as Data
Column {
    id:root;objectName:"sourceHealthPanel";spacing:10
    property var host:null
    property var season:null
    property var report:({rows:[]})
    property var history:[]
    function update(){report=Data.inspect(host?.view??{},Date.now(),history);history=report.rows;}
    onHostChanged:{history=[];update();}
    Connections {target:root.host;function onChanged(){if(!root.host?.active)root.history=[];if(root.visible)root.update();}}
    Timer {interval:400;repeat:true;running:root.visible;onTriggered:root.update()}
    Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:13;text:"宿主视图："+(root.report.accepted?"新鲜":"不可用／过期")+" · 在线队友 "+(root.report.online??0)+" · 接纳层拒绝 "+(root.report.rejected??"—")+" · 通信认证／权限等拒绝 "+(root.report.networkRejected??"—")}
    Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:12;color:Client.Theme.muted;text:"年龄来自原始 UTC 接收／测量时间；签名和评分不证明测量准确。只看已接纳快照，不增加权限，不转发数据。最多保留32个来源的本次会话记录。"}
    Repeater {
        model:root.report.rows.length
        Rectangle {
            required property int index
            readonly property var modelData:root.report.rows[index]
            width:root.width;height:Math.max(76,content.implicitHeight+24);color:Client.Theme.hudSolid
            Rectangle {width:3;height:parent.height;color:modelData.state==="有效"?Client.Theme.accent:Client.Theme.warning}
            GridLayout {id:content;x:14;y:12;width:parent.width-28;columns:width>700?3:1;columnSpacing:20
                Client.OperatorText {Layout.fillWidth:true;Layout.minimumWidth:0;wrapMode:Text.Wrap;text:modelData.key+"\n"+modelData.frame;size:13}
                Client.OperatorText {Layout.fillWidth:true;wrapMode:Text.Wrap;text:modelData.state+" · 年龄 "+Math.max(0,modelData.age)+"ms\n剩余 "+modelData.remaining+"ms · 冲突 "+modelData.conflicts;size:13;color:modelData.state==="有效"?Client.Theme.text:Client.Theme.warning}
                Client.OperatorText {Layout.fillWidth:true;wrapMode:Text.Wrap;text:modelData.scoreText+"\n当前观测 "+modelData.current;size:12;color:Client.Theme.muted}
            }
        }
    }
    Client.OperatorText {width:parent.width;height:implicitHeight;visible:root.report.rows.length===0;text:"尚无来源记录。启动态势并接入本机或授权队友观测后显示；不制造在线状态。";wrapMode:Text.Wrap;color:Client.Theme.muted}
}
