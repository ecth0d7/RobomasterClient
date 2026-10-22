import QtQuick
import QtQuick.Window
import "OperatorShortcutRegistry.js" as Registry

FocusScope {
    id:root
    objectName:"helpPanel"
    property int clientID:0
    property bool previewOnly:false
    property bool routesInstalled:false
    property var preferences:null
    property var inputState:null
    property bool heldOpen:false
    property bool editorMode:false
    property alias page:editor.page
    property alias query:editor.query
    readonly property var entries:editor.entries
    readonly property var guideEntries:editor.guideEntries
    readonly property var summaryEntries:[
        {key:binding("settings"),description:"设置连接身份、图传方向、鼠标比例、音量和界面显示。"},
        {key:binding("injury")==="`" ? "~" : binding("injury"),description:"按住查看模块连接、受伤来源和各项伤害比例。"},
        {key:binding("status"),description:"按住查看双方队列、血量和已接收的性能数据。"},
        {key:binding("ammo17")+" / "+binding("ammo42"),description:"步兵 O、英雄 I，打开对应弹种补给框；满足补给资格后可兑换。"},
        {key:binding("protocol"),description:"查看 MQTT 原值与字段时效，编辑并发送当前兵种适用的协议字段。"},
        {key:binding("shortcutPanel"),description:"查看、搜索快捷键，可随时改键并保存。"}
    ]
    signal openPanelRequested(string panel)
    signal closeRequested
    width:editorMode ? 1100 : summary.implicitWidth
    height:editorMode ? 650 : summary.implicitHeight
    function binding(id){return preferences ? preferences.sequence(id) : Registry.sequence(id,{});}
    function beginRecording(id){editorMode=true;heldOpen=false;editor.beginRecording(id);}
    onVisibleChanged:{
        if(visible)forceActiveFocus();
        else {
            heldOpen=false;editorMode=false;
            if(preferences)preferences.recording="";
            // 退出搜索框后释放本焦点域，否则隐藏的文本输入仍可能挡住 HUD 快捷键。
            focus=false;
        }
    }
    Keys.onEscapePressed:event=>{
        event.accepted=true;
        if(preferences?.recording){preferences.recording="";preferences.feedback="已取消按键录入";}
        else closeRequested();
    }
    Keys.onReleased:event=>{
        if(event.key===Qt.Key_F12 && heldOpen && !event.isAutoRepeat){event.accepted=true;closeRequested();}
    }
    Connections {
        target:root.Window.window
        function onActiveChanged(){if(root.Window.window?.active!==true && root.heldOpen)root.closeRequested();}
    }
    OperatorHelpSummaryForm {id:summary;anchors.fill:parent;visible:!root.editorMode;entries:root.summaryEntries}
    OperatorShortcutEditor {
        id:editor
        anchors.fill:parent;visible:root.editorMode
        clientID:root.clientID;previewOnly:root.previewOnly;routesInstalled:root.routesInstalled;preferences:root.preferences;inputState:root.inputState
        onOpenPanelRequested:panel=>{root.heldOpen=false;root.openPanelRequested(panel);}
        onCloseRequested:root.closeRequested()
    }
}
