import QtQuick
import QtQuick.Layouts
import "../../../qml/components" as Client
import "AuditData.js" as Data
Column {
    id:root;objectName:"seasonAuditPanel";spacing:10
    property var host:null
    property var season:null
    property int selectedIndex:0
    readonly property var profiles:season?.profiles??[]
    readonly property var selected:profiles[selectedIndex]??{}
    readonly property bool hostReady:host?.view?.schema==="rm.situation.view/1"
    readonly property var report:Data.audit(selected,season?.context,hostReady?{schema:"rm.situation.view/1"}:{})
    Client.OperatorConfigComboBox {objectName:"auditProfileChoice";width:parent.width;model:root.profiles.map(p=>p.season+" · "+p.rules_version+" · "+p.id);onActivated:index=>root.selectedIndex=index}
    Client.OperatorText {width:parent.width;height:implicitHeight;text:"只读就绪清单 · 查看规则不会切换赛季，也不创建协议字段";size:13;color:Client.Theme.muted;wrapMode:Text.Wrap}
    GridLayout {
      width:parent.width;columns:width>=900?2:1;columnSpacing:12;rowSpacing:12
      Repeater {
        model:root.report.rows.length
        Client.OperatorSection {
            required property int index
            readonly property var modelData:root.report.rows[index]
            Layout.fillWidth:true;Layout.minimumWidth:0
            implicitHeight:Math.max(104,note.implicitHeight+bodyTop+contentMargin)
            height:implicitHeight
            title:modelData.title+" / "+modelData.state;bodyTop:44;titleSize:14
            surfaceColor:Client.Theme.hudSolid
            Client.OperatorText {id:note;width:parent.width;height:implicitHeight;text:modelData.detail;wrapMode:Text.Wrap;size:13;color:Client.Theme.muted}
        }
    }
    }
    Client.OperatorText {width:parent.width;height:implicitHeight;wrapMode:Text.Wrap;size:12;color:Client.Theme.warning;text:"该清单不代表最终比赛验收。2027详细通信附件未取得的能力继续保持待接入，工程推论不作为官方机制。"}
    Repeater {model:root.report.capabilities
        Client.OperatorText {required property var modelData;width:root.width;height:implicitHeight;wrapMode:Text.Wrap;size:12;text:modelData.title+" · "+modelData.rule_state+" / "+modelData.data_state+" · "+modelData.page;color:Client.Theme.muted}
    }
}
