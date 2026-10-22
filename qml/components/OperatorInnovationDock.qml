import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    id:root
    objectName:"innovationDock"
    spacing:16
    readonly property var host:typeof battlefieldHost==="undefined"?null:battlefieldHost
    readonly property var season:typeof extensionServices==="undefined"?null:extensionServices.seasonConfiguration
    property bool journalRequested:false
    property string lifecycleFeedback:""
    function configureJournal(enabled) {
        journalRequested=enabled;
        lifecycleFeedback=host?.setJournalEnabled(enabled)===true
            ?"已提交时间线"+(enabled?"启用":"停用")+"；以面板运行状态为准"
            :"时间线尚未提交，请先启动态势协调器后重新启用";
    }
    readonly property bool situationActive:host?.active===true
    onSituationActiveChanged:if(situationActive && journalRequested)host.setJournalEnabled(true)
    Component.onDestruction:if(journalRequested && host?.active)host.setJournalEnabled(false)
    readonly property var features:[
        {folder:"season-audit",title:"赛季就绪审计",note:"对照现有版本目录，区分规则依据与实际接入能力"},
        {folder:"source-health",title:"来源健康诊断",note:"只读观察年龄、冲突和拒绝，不授予额外信任"},
        {folder:"tactical-timeline",title:"队内战术时间线",note:"人工短时标注与历史回看，不生成机器人命令"}]
    OperatorText {width:parent.width;height:implicitHeight;size:20;text:"终端实验工作区 / 2027";font.bold:true}
    OperatorText {width:parent.width;height:implicitHeight;size:13;color:Theme.muted;wrapMode:Text.Wrap;text:"各项默认关闭，独立加载。规则资料不等于线路可用；新插件缺失时基础功能照常运行。"}
    OperatorText {width:parent.width;height:implicitHeight;visible:root.lifecycleFeedback.length>0;text:root.lifecycleFeedback;wrapMode:Text.Wrap;size:12;color:Theme.muted}
    Repeater {
        model:root.features
        Column {
            id:feature
            required property var modelData
            required property int index
            width:root.width;spacing:10
            property bool enabledFeature:false
            onEnabledFeatureChanged:if(index===2)root.configureJournal(enabledFeature)
            Rectangle {
                width:parent.width;height:Math.max(76,head.implicitHeight+24);color:Theme.panelRaised;radius:2
                Rectangle {width:3;height:parent.height;color:feature.enabledFeature?Theme.accent:Theme.hudBorder}
                GridLayout {
                    id:head;x:16;y:12;width:parent.width-32;columns:width>680?2:1;columnSpacing:20
                    Column {Layout.fillWidth:true;spacing:4
                        OperatorText {width:parent.width;height:implicitHeight;text:feature.modelData.title;size:17}
                        OperatorText {width:parent.width;height:implicitHeight;text:feature.modelData.note;size:12;color:Theme.muted;wrapMode:Text.Wrap}
                    }
                    OperatorButton {objectName:"innovationToggle"+feature.index;text:feature.enabledFeature?"停用插件":"启用插件";primary:feature.enabledFeature;laboratory:true;Layout.preferredWidth:150;onClicked:feature.enabledFeature=!feature.enabledFeature}
                }
            }
            Loader {
                id:entry;width:parent.width;active:feature.enabledFeature
                source:"../../extensions/"+feature.modelData.folder+"/qml/Panel.qml"
                onLoaded:{item.host=root.host;item.season=root.season;}
            }
            OperatorText {width:parent.width;height:implicitHeight;visible:entry.status===Loader.Error;wrapMode:Text.Wrap;color:Theme.warning;text:"此可选插件未安装或未能加载；可停用，其它插件继续运行。"}
        }
    }
}
