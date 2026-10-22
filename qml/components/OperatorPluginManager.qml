import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "OperatorPluginGuide.js" as Guide

OperatorPluginManagerForm {
    id: root
    signal modelConfigurationRequested
    signal speechPanelRequested
    property var runtime: null
    property bool previewOnly: false
    property var previewModules: []
    property var mapRenderer: null
    property var heroVideo: typeof heroVideoReceiver === "undefined" ? null : heroVideoReceiver
    property var visionHost: typeof battlefieldHost === "undefined" ? null : battlefieldHost
    property string visionConfiguration: visionHost?.configurationFile ?? ""
    property string visionModel: ""
    property bool shareVision: false
    property bool speechSetupOpen: false
    property bool projectionSetupOpen: false
    property bool identitySetupOpen: false
    property bool configurationVisited: false
    configurationActive: configurationVisited
    onConfigurationExpandedChanged: if (configurationExpanded) configurationVisited=true
    Connections {
        target:root.configurationControl
        function onClicked() {root.configurationExpanded=!root.configurationExpanded;}
    }
    function startVisionModule(role, enabled) {
        if (!visionHost || previewOnly) return;
        visionHost.startModules(visionConfiguration,
            role === "vision-yolo" ? enabled : visionHost.visionEnabled,
            role === "vision-projectile" ? enabled : visionHost.projectileEnabled,
            shareVision, visionModel);
    }
    readonly property var modules: {
        const result=list(previewOnly ? previewModules : runtime?.modules);
        if(!previewOnly && mapRenderer)result.unshift({
            id:"map.battlefield3d",role:"map-3d",name:"2027场地GLB · M键立体态势地图",optional:true,
            managed:true,selected:true,missing:false,duplicate:false,enabled:mapRenderer.requested,
            status:mapRenderer.statusText,configuration_error:"",restart_required:false
        });
        if (!previewOnly && visionHost) for (let i=0;i<result.length;i++) {
            if (result[i].role === "battlefield") result[i]=Object.assign({},result[i],{
                name:"可选态势协调器 · 队内共享与融合",
                status:"视觉与吊射在各自进程运行；独立启停不重建队内会话"
            });
        }
        if(!previewOnly && heroVideo)result.push({
            id:"hero.lob.video",role:"hero-video",name:"部署状态下的低带宽视频",optional:true,
            managed:true,selected:true,enabled:heroVideo.enabled,missing:!heroVideo.available,duplicate:false,
            status:(heroVideo.format==="compact" ? "紧凑分片" : "连续H.264")+" · "+heroVideo.status,
            configuration_error:"",restart_required:false
        });
        if(!previewOnly && visionHost)for(const role of ["vision-projectile","vision-yolo"])result.unshift({
            id:role==="vision-yolo"?"vision.yolo.onnx":"vision.hero.projectile",role:role,
            name:role==="vision-yolo"?"普通UDP视频 · 机器人整机识别":"英雄吊射视频 · 弹丸运动候选与图像轨迹",
            optional:true,managed:true,selected:true,missing:false,duplicate:false,
            enabled:role==="vision-yolo"?visionHost.visionEnabled:visionHost.projectileEnabled,
            status:role==="vision-yolo"?(visionHost.view.vision?.status??"默认关闭；显式启动后才加载模型"):(visionHost.view.projectile?.status??"默认关闭；无插件不影响视频"),
            configuration_error:"",restart_required:false
        });
        return result;
    }
    function list(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length) && value.length >= 0
            ? Array.from(value) : [];
    }
    function roleName(role) {return ({"map-3d":"立体地图插件",mqtt:"选手端MQTT",protocol:"协议编解码",state:"遥测状态",input:"键鼠输入",policy:"命令策略",video:"图传解码","hero-video":"英雄吊射图传","vision-yolo":"YOLO整机识别插件","vision-projectile":"弹丸轨迹插件",decision:"模型建议",speech:"语音播报",bridge:"实验室画面桥接",aggregation:"队伍整合"})[role] ?? role;}
    function selectable(entry) {
        return !!(entry && runtime?.editable === true && entry.managed && !entry.selected && !entry.missing && !entry.duplicate);
    }
    function changeable(entry) {
        if(entry?.role==="map-3d")return !previewOnly && !!mapRenderer;
        return !!(entry && runtime?.editable === true && entry.managed && entry.selected
            && (entry.enabled || !entry.missing && !entry.duplicate && !entry.configuration_error));
    }
    function selectModule(index) {
        const entry = modules[index];
        if (selectable(entry)) runtime.selectPlugin(entry.role, entry.id);
    }
    function toggleModule(index) {
        const entry = modules[index];
        if (!changeable(entry))return;
        if(entry.role==="map-3d") {mapRenderer.setEnabled(!entry.enabled);return;}
        if(entry.role==="vision-yolo" || entry.role==="vision-projectile") {
            startVisionModule(entry.role,!entry.enabled);
        } else if(entry.role==="hero-video") {
            if(typeof heroVideo?.configure==="function")heroVideo.configure({enabled:!entry.enabled});
        } else runtime.setEnabled(entry.role, !entry.enabled);
    }
    featureConfiguration: Component {
        Item {
            implicitHeight: settings.implicitHeight+24
            ColumnLayout {
                id: settings
                x: 12; y: 12; width: parent.width-24; spacing: 8
                OperatorText { Layout.fillWidth: true; text: "可选视觉插件配置 · 下方模块行手动启停"; font.pixelSize: 16; wrapMode: Text.Wrap }
                OperatorText { Layout.fillWidth: true; text: "配置文件指定Python环境、类别与队友白名单。默认不启动；不把图像框当作场地位置。"; color: Theme.muted; wrapMode: Text.Wrap }
                OperatorConfigTextField {
                    objectName: "visionPluginConfiguration"
                    Layout.fillWidth: true; placeholderText: "视觉插件配置JSON的绝对路径"
                    text: root.visionConfiguration; onTextEdited: root.visionConfiguration=text
                    Accessible.name: "视觉插件配置文件"
                }
                OperatorConfigTextField {
                    objectName: "visionPluginModel"
                    Layout.fillWidth: true; placeholderText: "整机ONNX模型路径（留空沿用配置文件）"
                    text: root.visionModel; onTextEdited: root.visionModel=text
                    Accessible.name: "YOLO整机模型路径"
                }
                OperatorText {
                    Layout.fillWidth:true;color:Theme.muted;wrapMode:Text.Wrap
                    text:"阵营/编号辅助识别可在下方「身份辅助模型配置」中设置，或编辑完整JSON的vision.identity。整机仍由上方模型识别；身份不明确时保持未知。"
                }
                OperatorText {
                    Layout.fillWidth:true;color:Theme.muted;wrapMode:Text.Wrap
                    visible:root.visionHost?.view?.vision?.identity?.enabled===true
                    text:root.visionHost?.view?.vision?.identity?.status??""
                }
                CheckBox {
                    objectName: "visionPluginShare"
                    text: "队内共享识别结果（需已配置授权队友）"
                    palette.windowText: Theme.text
                    checked: root.shareVision; onToggled: root.shareVision=checked
                    Layout.fillWidth: true
                }
                Flow {
                    Layout.fillWidth: true; spacing: 8
                    OperatorButton {
                        objectName: "applyVisionConfiguration"
                        width: Math.min(280,parent.width)
                        text: "应用视觉 / 队内通信配置"; enabled: root.runtime?.editable === true && !!root.visionHost
                        onClicked: root.visionHost.startModules(root.visionConfiguration,root.visionHost.visionEnabled,root.visionHost.projectileEnabled,root.shareVision,root.visionModel)
                    }
                }
                OperatorText { Layout.fillWidth: true; color: Theme.muted; wrapMode: Text.Wrap; text: "接收端可保持YOLO关闭；加载含授权队友的通信配置即可接收。共享设置在应用配置或下次启用时生效。" }
                Loader {
                    Layout.fillWidth:true;active:!!root.visionHost
                    source:active?Qt.resolvedUrl("../../extensions/yolo-vision/qml/FilterSetup.qml"):""
                    onLoaded:{
                        item.host=Qt.binding(()=>root.visionHost);
                        item.editable=Qt.binding(()=>root.runtime?.editable===true);
                        item.configurationFile=Qt.binding(()=>root.visionConfiguration);
                        item.saved.connect(file=>root.visionConfiguration=file);
                    }
                }
                CheckBox {
                    objectName:"visionProjectionSetupToggle"
                    text:"展开移动相机定位配置";palette.windowText:Theme.text
                    checked:root.projectionSetupOpen;onToggled:root.projectionSetupOpen=checked
                }
                Loader {
                    Layout.fillWidth:true;active:root.projectionSetupOpen
                    sourceComponent:Component {
                        OperatorVisionProjectionSetup {
                            width:parent?.width??600;host:root.visionHost;editable:root.runtime?.editable===true
                            configurationFile:root.visionConfiguration;modelFile:root.visionModel
                            onSaved:file=>root.visionConfiguration=file
                        }
                    }
                }
                CheckBox {
                    objectName: "visionIdentitySetupToggle"
                    text: "展开身份辅助模型配置"; palette.windowText: Theme.text
                    checked: root.identitySetupOpen; onToggled: root.identitySetupOpen = checked
                }
                Loader {
                    Layout.fillWidth: true; active: root.identitySetupOpen
                    sourceComponent: Component {
                        OperatorVisionIdentitySetup {
                            width: parent?.width ?? 600; host: root.visionHost; editable: root.runtime?.editable === true
                            configurationFile: root.visionConfiguration; modelFile: root.visionModel
                            onSaved: file => root.visionConfiguration = file
                        }
                    }
                }
                CheckBox {
                    text: "展开语音启动配置"; palette.windowText: Theme.text
                    checked: root.speechSetupOpen; onToggled: root.speechSetupOpen=checked
                }
                ColumnLayout {
                    visible: root.speechSetupOpen; Layout.fillWidth: true; spacing: 8
                    OperatorText { Layout.fillWidth: true; text: "仅配置本次运行；需在准备阶段操作。Piper服务与音色模型须先在本机就绪。"; color: Theme.muted; wrapMode: Text.Wrap }
                    OperatorConfigComboBox { id: speechEngine; Layout.fillWidth: true; model: ["eSpeak本地程序", "Piper本地HTTP服务"]; Accessible.name: "语音插件引擎" }
                    OperatorConfigTextField { id: speechExecutable; Layout.fillWidth: true; visible: speechEngine.currentIndex===0; placeholderText: "espeak-ng程序绝对路径（留空查找PATH）"; Accessible.name: "语音合成程序" }
                    OperatorConfigTextField { id: speechEndpoint; Layout.fillWidth: true; visible: speechEngine.currentIndex===1; text: "http://127.0.0.1:5002/synthesize"; placeholderText: "本地HTTP合成接口，返回WAV"; Accessible.name: "Piper合成接口" }
                    OperatorConfigTextField { id: speechVoice; Layout.fillWidth: true; placeholderText: speechEngine.currentIndex===0 ? "发音人，例如cmn" : "服务音色ID（可留空）"; Accessible.name: "语音音色" }
                    OperatorConfigTextField { id: speechPlayer; Layout.fillWidth: true; text: "/usr/bin/paplay"; placeholderText: "播放器绝对路径"; Accessible.name: "语音播放器" }
                    CheckBox { id: speechPlay; text: "合成后播放声音（关闭时仅合成）"; palette.windowText: Theme.text }
                    OperatorButton {
                        text: "应用语音配置并启动"; enabled: root.runtime?.editable === true
                        onClicked: {
                            let values={player:speechPlayer.text,playback:speechPlay.checked};
                            if(speechEngine.currentIndex===0)values=Object.assign(values,{executable:speechExecutable.text,voice:speechVoice.text || "cmn"});
                            else values=Object.assign(values,{endpoint:speechEndpoint.text,model:speechVoice.text});
                            root.runtime.configureSpeech(speechEngine.currentIndex===0?"speech.espeak":"speech.piper-http",values);
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true; spacing: 8
                    OperatorButton { text: "模型提供者配置"; onClicked: root.modelConfigurationRequested() }
                    OperatorButton { text: "打开语音面板"; onClicked: root.speechPanelRequested() }
                }
                OperatorText { Layout.fillWidth: true; text: root.visionHost?.status??"可选视觉宿主未安装"; color: Theme.muted; wrapMode: Text.Wrap }
            }
        }
    }
    refreshEnabled: !!runtime && !previewOnly
    descriptionText: previewOnly ? "离线绘制，不发现或加载本机插件。" : runtime
        ? runtime.editable ? "可随时启停可选服务。核心端点随主程序运行，替换需重启。" : "配置宿主未就绪、身份未确认或正在切换服务；本地立体地图仍可切换。"
        : "当前宿主尚未公开插件管理接口。"
    emptyText: "尚无插件清单；单机界面与选手端连接保持独立。"
    statusText: runtime?.status || "启停只作用于当前进程，沿用启动配置；密钥和令牌不显示。实验室原始桥接不等于可信队伍汇总。"
    moduleCount: modules.length
    moduleDelegate: Component {
        OperatorPluginModuleRowForm {
            id: module
            required property int index
            readonly property var entry: root.modules[index] ?? ({})
            objectName: "pluginManagerModule_" + index
            width: root.moduleDelegateWidth
            roleText: root.roleName(entry.role) || "未提供角色"
            identityText: entry.id || "未提供插件ID"
            classificationText: typeof entry.optional !== "boolean" ? "核心／可选角色状态未提供"
                : entry.role==="map-3d" ? "本地显示 · 可缺省／停用" : entry.optional ? "可选服务 · 可缺省／停用" : "核心端点 · 启动时选择"
            nameText: Guide.summary(entry.id,entry.name || "未提供名称")
            statusText: (entry.duplicate ? "插件ID重复，拒绝启用。 " : "")
                + (entry.missing ? "文件缺失或元数据不兼容。 " : "")
                + Guide.status(entry.configuration_error || entry.status || "状态未提供")
            usageText: Guide.guide(entry.id,entry.role)
            warning: !!(entry.error || entry.missing || entry.duplicate || entry.configuration_error)
            selectText: entry.selected ? "当前选择" : entry.optional ? "选择此插件" : "修改启动配置"
            selectEnabled: root.selectable(entry)
            enableText: entry.role==="map-3d" ? entry.enabled ? "停用立体地图" : "启用立体地图" : entry.enabled ? entry.optional ? "停用服务" : "核心端点运行中" : "启用服务"
            enablePrimary: !!(entry.optional && entry.enabled)
            enableEnabled: root.changeable(entry)
            footerText: entry.role==="map-3d" ? "M键打开时加载；停用后显示二维地图" : entry.enabled && entry.optional ? "启用不等于已连接" : entry.restart_required ? "运行时不卸载核心依赖" : "显式操作才启动"
            minimumHeight: root.rowMinimumHeight
            contentMargin: root.rowContentMargin
            topInset: root.rowTopInset
            bottomInset: root.rowBottomInset
            columnGap: root.rowColumnGap
            rowGap: root.rowGap
            breakpoint: root.rowBreakpoint
            identityWidth: root.rowIdentityWidth
            identitySpacing: root.rowIdentitySpacing
            identityHintGap: root.rowIdentityHintGap
            roleMinimumHeight: root.rowRoleMinimumHeight
            identityMinimumHeight: root.rowIdentityMinimumHeight
            classificationMinimumHeight: root.rowClassificationMinimumHeight
            statusSpacing: root.rowStatusSpacing
            nameMinimumHeight: root.rowNameMinimumHeight
            statusMinimumHeight: root.rowStatusMinimumHeight
            actionWidth: root.rowActionWidth
            controlHeight: root.rowControlHeight
            actionTop: root.rowActionTop
            actionSpacing: root.rowActionSpacing
            actionNoteGap: root.rowActionNoteGap
            actionNoteMinimumHeight: root.rowActionNoteMinimumHeight
            separatorInset: root.rowSeparatorInset
            separatorWidth: root.rowSeparatorWidth
            roleSize: root.rowRoleSize
            identitySize: root.rowIdentitySize
            classificationSize: root.rowClassificationSize
            nameSize: root.rowNameSize
            noteSize: root.noteSize
            actionNoteSize: root.rowActionNoteSize
            actionSize: root.actionSize
            surfaceColor: root.rowSurfaceColor
            outlineColor: root.outlineColor
            textColor: root.textColor
            mutedColor: root.mutedColor
            warningColor: root.warningColor
            separatorColor: root.separatorColor
            fontFamily: root.fontFamily
            identityFontFamily: root.identityFontFamily
            Connections { target: module.helpControl; function onClicked() { module.usageExpanded=!module.usageExpanded; } }
            Connections { target: module.selectControl; function onClicked() { root.selectModule(module.index); } }
            Connections { target: module.enableControl; function onClicked() { root.toggleModule(module.index); } }
        }
    }
    Connections { target: root.refreshControl; function onClicked() { if (root.refreshEnabled) root.runtime.refresh(); } }
}
