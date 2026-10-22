import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../qml/components" as Client

ColumnLayout {
    id:root
    objectName:"visionFilterSetup"
    property var host:null
    property bool editable:false
    property string configurationFile:""
    property string feedback:""
    signal saved(string file)
    spacing:8
    function load() {
        const value=host?.filterConfiguration(configurationFile) ?? {};
        mode.currentIndex=value.mode==="all"?1:0;
        feedback="";
    }
    Component.onCompleted:load()
    Client.OperatorText {Layout.fillWidth:true;text:"视觉显示与共享对象";size:16;wrapMode:Text.Wrap}
    Client.OperatorConfigComboBox {
        id:mode;objectName:"visionTargetFilter"
        Layout.fillWidth:true;enabled:root.editable
        model:["敌方与阵营未知（隐藏已确认己方）","全部目标（含己方候选）"]
        Accessible.name:"视觉显示与共享目标范围"
    }
    Client.OperatorText {
        Layout.fillWidth:true;color:Client.Theme.muted;wrapMode:Text.Wrap
        text:"默认隐藏已确认的己方候选。阵营尚未识别或本机阵营未确定时保留未知目标；不会把未知自动当成敌方。此选项同时影响本机识别框、地图观测及对外视觉共享，不改变雷达数据，也不减少整幅图像的模型计算。"
    }
    Flow {
        Layout.fillWidth:true;spacing:8
        Client.OperatorButton {text:"从当前JSON读取";enabled:!!root.host;onClicked:root.load()}
        Client.OperatorButton {
            objectName:"saveVisionFilter";text:"保存目标范围"
            enabled:root.editable && !!root.host
            onClicked:{
                if(root.host.saveFilterConfiguration(root.configurationFile,{mode:mode.currentIndex===1?"all":"enemy_and_unknown"})) {
                    root.feedback="已保存完整配置副本；点击上方应用按钮后生效，保存不会启动模型。";
                    root.saved(root.host.configurationFile);
                } else root.feedback=root.host.status;
            }
        }
    }
    Client.OperatorText {Layout.fillWidth:true;visible:root.feedback.length>0;text:root.feedback;color:Client.Theme.muted;wrapMode:Text.Wrap}
}
