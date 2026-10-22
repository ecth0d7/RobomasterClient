import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "UiFormat.js" as Format
import "OperatorData.js" as Data
import "OperatorStartupPolicy.js" as Startup

OperatorPanelFrame {
    id: root
    property int clientID: 0
    property int selectedRobot: 3
    property bool blue: false
    property bool connecting: false
    property bool connected: false
    property bool previewOnly: false
    property string connectionStatus: "未连接"
    property var connection: null
    property var videoState: null
    property var seasonRuntime: null
    readonly property bool wireAllowed: !seasonRuntime || seasonRuntime.officialConnectionAllowed === true
    readonly property bool nextSeason: seasonRuntime?.current?.season === 2027
    property string draftHost: ""
    property string draftPort: "3333"
    property string draftVideoBind: "0.0.0.0"
    property string draftVideoPort: "3334"
    property string draftCodec: "hevc"
    property string draftSource: ""
    property string draftSourcePort: "0"
    property string draftGroup: ""
    readonly property string actualHost: connection?.host ?? ""
    readonly property int actualPort: connection?.port ?? 3333
    readonly property bool targetEditable: wireAllowed && (previewOnly || connection?.canChangeTarget !== false)
    readonly property bool videoEditable: wireAllowed && (previewOnly || videoState?.canConfigure === true)
    readonly property bool endpointChanged: draftHost.trim()!==actualHost || Number(draftPort)!==actualPort
    readonly property bool endpointValid: Startup.hostValid(draftHost.trim()) && Startup.port(draftPort)!==undefined
    readonly property bool sourcePortValid: /^\d{1,5}$/.test(draftSourcePort) && Number(draftSourcePort)<=65535
    readonly property bool videoValid: Startup.bindPlausible(draftVideoBind.trim()) && Startup.port(draftVideoPort)!==undefined
        && (!draftSource.trim() || Startup.bindPlausible(draftSource.trim())) && sourcePortValid
        && (!draftGroup.trim() || Startup.bindPlausible(draftGroup.trim()))
    readonly property var savedVideo: videoState?.settings ?? ({bind:"0.0.0.0",port:3334,codec:"hevc",source_address:"",source_port:0,multicast_group:""})
    readonly property bool videoDirty: draftVideoBind.trim()!==savedVideo.bind || Number(draftVideoPort)!==savedVideo.port
        || draftCodec!==savedVideo.codec || draftSource.trim()!==(savedVideo.source_address ?? "")
        || Number(draftSourcePort)!==(savedVideo.source_port ?? 0) || draftGroup.trim()!==(savedVideo.multicast_group ?? "")
    readonly property int selectedID: selectedRobot + (blue ? 100 : 0)
    property color teamColor: blue ? Theme.blue : Theme.red
    readonly property bool currentIdentity: !previewOnly && connected && selectedID===clientID && !endpointChanged
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    signal loginRequested(int robotID)
    signal seasonRequested
    signal sessionRequested(var options)
    signal disconnectRequested
    signal videoConfigureRequested(var options)
    signal videoRestartRequested
    signal videoStopRequested
    title: "连接与登录 · MQTT / UDP / 机器人身份"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width:1440
    height:848
    function videoOptions() {
        return {bind:draftVideoBind.trim(),port:Number(draftVideoPort),codec:draftCodec,
            source_address:draftSource.trim(),source_port:Number(draftSourcePort),multicast_group:draftGroup.trim()};
    }
    function reload() {
        draftHost=actualHost || (previewOnly ? "127.0.0.1" : "192.168.12.1");draftPort=String(actualPort);
        draftVideoBind=savedVideo.bind;draftVideoPort=String(savedVideo.port);draftCodec=savedVideo.codec;
        draftSource=savedVideo.source_address ?? "";draftSourcePort=String(savedVideo.source_port ?? 0);draftGroup=savedVideo.multicast_group ?? "";
        if(Format.validLogin(clientID)){selectedRobot=clientID%100;blue=clientID>100;}
    }
    function connectSelected(force) {
        if (!wireAllowed) return;
        if(!endpointValid || !Format.validLogin(selectedID) || videoDirty && (!videoEditable || !videoValid))return;
        if(previewOnly){loginRequested(selectedID);return;}
        sessionRequested({robot_id:selectedID,host:draftHost.trim(),port:Number(draftPort),
            video:videoDirty ? videoOptions() : null,reconnect:force===true});
    }
    function applyVideo() {if(videoEditable && videoValid)videoConfigureRequested(videoOptions());}
    onVisibleChanged:if(visible){reload();forceActiveFocus();}

    Flickable {
        id: connectionViewport
        objectName: "loginConnectionViewport"
        width: parent.width
        height: Math.max(0, footer.y - 12)
        contentWidth: width
        contentHeight: connectionContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Item {
            id: connectionContent
            width: connectionViewport.width - 12
            height: sessionHint.y + sessionHint.height
            OperatorText {width:parent.width;height:28;text:root.previewOnly ? "离线预览 · 不连接MQTT、不监听UDP、不控制机器人" : !root.wireAllowed ? root.seasonRuntime.connectionReason : "2026官方比赛数据经选手端导出；MQTT与UDP独立配置，修改后显式应用";size:12;color:root.wireAllowed ? Theme.muted : Theme.warning}
            Row {
                y:38;width:parent.width;spacing:10;height:38
                OperatorText {width:94;height:38;text:"MQTT目标";size:12;color:Theme.muted}
                OperatorInput {objectName:"loginBrokerHost";width:parent.width-604;height:38;label:"MQTT服务器地址";enabled:root.targetEditable;text:root.draftHost;maximumLength:253;onTextEdited:root.draftHost=text;onAccepted:root.connectSelected(false)}
                OperatorInput {objectName:"loginBrokerPort";width:96;height:38;label:"MQTT端口";enabled:root.targetEditable;text:root.draftPort;maximumLength:5;inputMethodHints:Qt.ImhDigitsOnly;onTextEdited:root.draftPort=text;onAccepted:root.connectSelected(false)}
                OperatorButton {width:82;height:38;text:"本机";enabled:root.targetEditable;onClicked:{root.draftHost="127.0.0.1";root.draftPort="3333";}}
                OperatorButton {width:96;height:38;text:"选手端";enabled:root.targetEditable;onClicked:{root.draftHost="192.168.12.1";root.draftPort="3333";}}
                OperatorButton {objectName:"loginReconnect";width:96;height:38;text:"重新连接";enabled:root.wireAllowed && root.endpointValid && Format.validLogin(root.selectedID);onClicked:root.connectSelected(true)}
                OperatorButton {width:80;height:38;text:"断开";enabled:root.connected || root.connecting;onClicked:root.disconnectRequested()}
            }
            OperatorText {y:80;width:parent.width;height:24;text:root.previewOnly ? "mock连接地址" : "实际MQTT "+root.actualHost+":"+root.actualPort+" · "+root.connectionStatus;size:11;color:!root.endpointValid ? Theme.warning : Theme.muted}
            Row {
                y:112;width:parent.width;spacing:10;height:38
                OperatorText {width:94;height:38;text:"UDP监听";size:12;color:Theme.muted}
                OperatorInput {objectName:"loginVideoBind";width:parent.width-694;height:38;label:"本机UDP监听IP";placeholderText:"本机IP或0.0.0.0";enabled:root.videoEditable;text:root.draftVideoBind;maximumLength:128;onTextEdited:root.draftVideoBind=text}
                OperatorInput {objectName:"loginVideoPort";width:96;height:38;label:"UDP监听端口";enabled:root.videoEditable;text:root.draftVideoPort;maximumLength:5;inputMethodHints:Qt.ImhDigitsOnly;onTextEdited:root.draftVideoPort=text}
                OperatorSelect {width:150;height:38;label:"视频编码";enabled:root.videoEditable;model:["HEVC / H.265","H.264","自动识别"];currentIndex:["hevc","h264","auto"].indexOf(root.draftCodec);onActivated:root.draftCodec=["hevc","h264","auto"][currentIndex]}
                OperatorButton {objectName:"loginApplyVideo";width:118;height:38;text:"应用UDP";enabled:root.videoEditable && root.videoValid && root.videoDirty;onClicked:root.applyVideo()}
                OperatorButton {width:96;height:38;text:"重新接收";enabled:root.videoEditable && !!root.videoState;onClicked:{if(root.videoDirty)root.applyVideo();else root.videoRestartRequested();}}
                OperatorButton {width:80;height:38;text:"停止";enabled:root.videoState?.running===true;onClicked:root.videoStopRequested()}
            }
            OperatorText {
                y:154;width:parent.width;height:26;size:11
                text:root.previewOnly ? "UDP离线绘制" : (root.videoState?.diagnostics?.bound===true ? "已绑定 " : root.videoState?.running===true ? "已请求监听 " : "已停止 ")
                    +(root.savedVideo.bind ?? "—")+":"+(root.savedVideo.port ?? "—")+" · "+(root.videoState?.status ?? "当前宿主未提供图传运行配置")
                    +" · 监听地址填写本机IP；远端发送者填下行来源过滤"
                color:Theme.muted
            }
            Row {
                y:194;width:parent.width;spacing:10;height:38
                OperatorText {width:94;height:38;text:"来源过滤";size:12;color:Theme.muted}
                OperatorInput {objectName:"loginVideoSource";width:(parent.width-400)/2;height:38;label:"允许的视频发送源IP，留空自动锁定";placeholderText:"发送源IP · 留空自动锁定单一来源";enabled:root.videoEditable && (root.previewOnly || root.videoState?.capabilities?.source_filter===true);text:root.draftSource;maximumLength:128;onTextEdited:root.draftSource=text}
                OperatorInput {width:86;height:38;label:"发送源端口，0为不限";placeholderText:"源端口0";enabled:root.videoEditable && (root.previewOnly || root.videoState?.capabilities?.source_filter===true);text:root.draftSourcePort;maximumLength:5;inputMethodHints:Qt.ImhDigitsOnly;onTextEdited:root.draftSourcePort=text}
                OperatorText {width:74;height:38;text:"组播组";size:12;color:Theme.muted}
                OperatorInput {objectName:"loginVideoMulticast";width:(parent.width-400)/2;height:38;label:"组播订阅地址，单播留空";placeholderText:"组播地址 · 普通单播留空";enabled:root.videoEditable && (root.previewOnly || root.videoState?.capabilities?.multicast===true);text:root.draftGroup;maximumLength:128;onTextEdited:root.draftGroup=text}
                OperatorButton {width:96;height:38;text:"清除过滤";enabled:root.videoEditable;onClicked:{root.draftSource="";root.draftSourcePort="0";root.draftGroup="";}}
            }
            Row {
                y:250;width:parent.width;spacing:12
                visible: !root.nextSeason
                Repeater {
                    model:[{blue:false,title:"红方"},{blue:true,title:"蓝方"}]
                    OperatorButton {
                        required property var modelData
                        width:172;height:38;text:modelData.title;enabled:root.targetEditable
                        primary:root.blue===modelData.blue
                        onClicked:root.blue=modelData.blue
                    }
                }
                OperatorText {width:parent.width-368;height:38;text:root.targetEditable ? "可反复选择身份；连接中也可切换选择，再显式重连" : "当前赛季或连接宿主不允许修改身份";size:12;color:root.targetEditable ? Theme.muted : Theme.warning}
            }
            Grid {
                id: roleGrid
                objectName: "loginRoleGrid"
                y:308;width:parent.width;columns:5;spacing:12
                visible: !root.nextSeason
                Repeater {
                    model:Format.loginRoles
                    Button {
                        id: robot
                        required property int modelData
                        readonly property int robotID:modelData+(root.blue ? 100 : 0)
                        objectName: "loginRobot_" + modelData
                        width:(roleGrid.width-(roleGrid.columns-1)*roleGrid.spacing)/roleGrid.columns;height:136;enabled:root.targetEditable
                        checkable:true;autoExclusive:true;checked:root.selectedRobot===modelData
                        Accessible.name:(root.blue ? "蓝方" : "红方")+Format.role(modelData)+"，登录编号 "+robotID
                        contentItem:Item {
                            opacity:robot.enabled ? 1 : .4
                            Image {anchors.horizontalCenter:parent.horizontalCenter;y:4;width:124;height:72;visible:robot.modelData!==9;source:visible ? Data.portrait(robot.robotID) : "";fillMode:Image.PreserveAspectFit;mipmap:true}
                            OperatorRadarGlyph {anchors.horizontalCenter:parent.horizontalCenter;y:8;width:64;height:64;visible:robot.modelData===9;accent:root.teamColor}
                            OperatorText {y:82;width:parent.width;height:24;text:Format.role(robot.modelData);horizontalAlignment:Text.AlignHCenter;size:14}
                            OperatorText {y:108;width:parent.width;height:20;text:"ID "+robot.robotID;numeric:true;horizontalAlignment:Text.AlignHCenter;size:11;color:robot.checked ? root.teamColor : Theme.muted}
                        }
                        background:Rectangle {color:robot.down || robot.hovered ? Theme.hudHover : Theme.hudSurface;opacity:robot.enabled ? 1 : .4;OperatorOutline {color:robot.activeFocus ? Theme.text : robot.checked ? root.teamColor : Theme.hudBorder;emphasized:robot.checked || robot.activeFocus}}
                        onClicked:root.selectedRobot=modelData
                    }
                }
            }
            OperatorSection {
                id: seasonRoles
                y: 250; width: parent.width; height: 336; visible: root.nextSeason
                title: "2027 角色目录 · 尚无核验的线路身份与登录协议"
                Column {
                    width: parent.width; spacing: 9
                    OperatorText { width: parent.width; height: 42; text: "这里展示正式规则角色，不把旧英雄／工程身份重命名，不猜蓝方ID。详细线路定义取得后再启用终端登录。"; size: 13; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    Repeater {
                        model: root.seasonRuntime?.current?.roster ?? []
                        OperatorText {
                            required property var modelData
                            width: parent.width; height: 28; size: 14
                            text: "规则编号 " + (modelData.rule_number_label ?? "—") + "    " + modelData.title + "    主力 " + modelData.count
                        }
                    }
                }
            }
            Rectangle {
                id: selectionStatus
                objectName: "loginSelectionStatus"
                // 状态区跟随完整角色网格；新增身份时不能覆盖最后一行。
                y:(root.nextSeason ? seasonRoles.y+seasonRoles.height : roleGrid.y+roleGrid.height)+14;width:parent.width;height:64;color:Theme.hudSurface
                BorderImage {anchors.fill:parent;anchors.margins:Theme.hudStroke(root.hudScale,false);source:"../resources/engine-137/sprites/ServerUI_LoginStatusBg.png";border {left:6;top:6;right:6;bottom:6}}
                OperatorOutline {}
                OperatorText {x:12;y:7;width:parent.width-24;height:23;text:root.nextSeason ? "当前配置：2027正式规则 · 详细协议／官方适配器待接通" : "当前选择："+(root.blue ? "蓝方 " : "红方 ")+Format.role(root.selectedRobot)+" · ID "+root.selectedID+" → "+root.draftHost+":"+root.draftPort;size:13;color:root.nextSeason ? Theme.warning : root.teamColor}
                OperatorText {x:12;y:32;width:parent.width-24;height:24;text:root.videoState?.configurationStatus || root.connectionStatus;size:11;color:Theme.muted}
            }
            OperatorText {id: sessionHint;y:selectionStatus.y+selectionStatus.height+8;width:parent.width;height:26;size:11;color:!root.endpointValid || root.videoDirty && !root.videoValid ? Theme.warning : Theme.muted;text:!root.endpointValid ? "请填写有效MQTT地址与端口" : root.videoDirty && !root.videoValid ? "UDP参数格式有误；尚未应用" : root.videoDirty ? "UDP有未应用修改；连接按钮会一并提交，MQTT与图传结果独立显示" : "本页修改作用于本次进程；切换会清除旧流画面与旧机器人遥测"}
        }
    }
    Row {
        id: footer
        objectName: "loginFooter"
        y:parent.height-44;width:parent.width;spacing:12
        OperatorButton {width:180;height:38;text:"撤销未应用修改";onClicked:root.reload()}
        OperatorButton {width:172;height:38;text:"赛季与规则";onClicked:root.seasonRequested()}
        Item {width:Math.max(0,parent.width-608);height:38}
        OperatorButton {
            objectName:"loginConnectSelected";width:220;height:38;primary:true
            enabled:root.wireAllowed && root.endpointValid && Format.validLogin(root.selectedID) && (!root.connecting || root.endpointChanged || root.selectedID!==root.clientID || root.videoDirty)
                && (!root.videoDirty || root.videoEditable && root.videoValid)
            text:root.previewOnly ? "查看所选界面" : root.currentIdentity ? root.videoDirty ? "应用图传并返回" : "返回当前界面" : root.connecting && !root.endpointChanged && root.selectedID===root.clientID ? "正在连接…" : "连接所选身份与地址"
            onClicked:root.connectSelected(false)
        }
    }
    OperatorActionShortcut {scopeItem:root;actionId:"loginConnect";available:root.visible;onActivated:root.connectSelected(false)}
    OperatorActionShortcut {scopeItem:root;actionId:"loginReconnect";available:root.visible;onActivated:root.connectSelected(true)}
    OperatorActionShortcut {scopeItem:root;actionId:"loginVideo";available:root.visible && root.videoEditable;onActivated:root.applyVideo()}
    OperatorActionShortcut {scopeItem:root;actionId:"loginTeam";available:root.visible && root.targetEditable;onActivated:root.blue=!root.blue}
    Repeater {
        model:Format.loginRoles
        Item {
            id: robotKey
            required property int modelData
            OperatorActionShortcut {scopeItem:root;actionId:"loginRobot"+robotKey.modelData;available:root.visible && root.targetEditable;onActivated:root.selectedRobot=robotKey.modelData}
        }
    }
}
