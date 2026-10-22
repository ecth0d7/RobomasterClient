import QtQuick
import "UiFormat.js" as Format
import "OperatorDiagnostics.js" as Diagnostics

OperatorPanelFrame {
    id: root
    property var services: null
    property var connection: null
    property var video: null
    property var telemetry: null
    property bool previewOnly: false
    property var mapRenderer: null
    property int selectedTab: 0
    property var visitedTabs: []
    readonly property var groupEntries: visible ? Diagnostics.groups(telemetry) : []
    readonly property var groupSummary: Diagnostics.summary(groupEntries)
    readonly property var mqtt: connection?.receiveDiagnostics ?? ({})
    readonly property var videoDetails: video?.diagnostics ?? ({})
    readonly property var history: sequence(connection?.commandHistory)
    signal providerRequested
    signal speechRequested
    signal settingsRequested
    signal seasonRequested
    signal openExtensionPanelRequested(string packageId, string panelId)
    title: "服务状态与诊断"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1360
    height: 780

    function visitCurrentTab() {
        if (!visible || selectedTab<0 || selectedTab>=tabTitles.length || selectedTab===6 || visitedTabs.includes(selectedTab)) return;
        visitedTabs=visitedTabs.concat([selectedTab]);
    }
    onVisibleChanged: if (visible) visitCurrentTab()
    onSelectedTabChanged: visitCurrentTab()
    Component.onCompleted: visitCurrentTab()
    function serviceState(details) {
        return details?.busy === true ? "busy" : details?.active === true ? "ok" : "unknown";
    }
    readonly property var overview: [
        {title: "MQTT / 协议", status: connection?.status ?? "未提供连接状态",
         state: connection?.connected === true ? "ok" : connection?.connecting === true ? "busy" : "unknown", rows: [
            {label: "已收到消息", value: Diagnostics.number(mqtt.received), numeric: true},
            {label: "发送提交／拒绝", value: Diagnostics.number(mqtt.publish_submitted) + " / " + Diagnostics.number(mqtt.publish_rejected), numeric: true}]},
        {title: "UDP 图传", status: video?.status ?? "未提供图传状态",
         state: typeof videoDetails.last_frame_age_ms === "number" ? videoDetails.last_frame_age_ms > 2000 ? "warning" : "ok" : "unknown", rows: [
            {label: "图像交付速率", value: Diagnostics.number(video?.fps, " FPS", 1), numeric: true},
            {label: "最近图像年龄", value: Diagnostics.number(videoDetails.last_frame_age_ms, " ms"), numeric: true}]},
        {title: "遥测时效", status: groupSummary.total > 0 ? "有效 " + groupSummary.fresh + " · 旧 " + groupSummary.stale + " · 未收到 " + groupSummary.missing : "尚无分组状态",
         state: groupSummary.stale > 0 ? "warning" : groupSummary.fresh > 0 ? "ok" : "unknown", rows: [
            {label: "状态分组数", value: groupSummary.total > 0 ? String(groupSummary.total) : "—", numeric: true},
            {label: "最近本地操作", value: history.length ? Diagnostics.commandResult(history[0]) : "尚无记录"}]},
        {title: "实验室原始桥接", status: services?.bridgeStatus ?? "未提供服务状态", state: serviceState(services?.bridgeDetails), rows: [
            {label: "连接数", value: Diagnostics.number(services?.bridgeDetails?.connections), numeric: true},
            {label: "待发送字节", value: Diagnostics.number(services?.bridgeDetails?.pending_output_bytes), numeric: true}]},
        {title: "队伍汇总 · 可选插件", status: services?.aggregationStatus ?? "生产端未接通 · 本机路径独立", state: services?.aggregationDetails?.view_usable === true ? "ok" : "unknown", rows: [
            {label: "汇总视图", value: services?.aggregationView?.view_id ?? "—"},
            {label: "版本", value: Diagnostics.number(services?.aggregationView?.revision), numeric: true}]},
        {title: "模型建议", status: services?.decisionStatus ?? "未提供服务状态", state: serviceState(services?.decisionDetails), rows: [
            {label: "当前模型", value: services?.decisionDetails?.model ?? "—"},
            {label: "输入证据", value: Diagnostics.boolean(services?.decisionInputFresh, "有效", "等待新数据")}]},
        {title: "AI 输入范围", status: services?.decisionInputStatus ?? "生产模式选择尚未接通", state: "unknown", rows: [
            {label: "实际输入", value: services?.decisionTrace?.input_mode === "team" ? "队伍整合视图" : services?.decisionTrace?.input_mode === "local" ? "本机机器人数据" : "未提供"},
            {label: "降级原因", value: services?.decisionTrace?.degradation_reason ?? "—"}]},
        {title: "语音播报", status: services?.speechStatus ?? "未提供服务状态", state: serviceState(services?.speechDetails), rows: [
            {label: "语音引擎", value: services?.speechDetails?.engine ?? "—"},
            {label: "待播报条数", value: Diagnostics.number(services?.speechDetails?.queued), numeric: true}]}
    ]
    readonly property var linkCards: [
        {title: "MQTT 收发 / 协议解析", rows: [
            {label: "连接状态", value: connection?.status ?? "—", detail: true},
            {label: "接收消息", value: Diagnostics.number(mqtt.received)},
            {label: "交付状态层", value: Diagnostics.number(mqtt.delivered)},
            {label: "丢弃消息", value: Diagnostics.number(mqtt.dropped)},
            {label: "排队消息", value: Diagnostics.number(mqtt.pending_messages)},
            {label: "排队字节", value: Diagnostics.number(mqtt.pending_bytes)},
            {label: "队列消息上限", value: Diagnostics.number(mqtt.maximum_messages)},
            {label: "队列字节上限", value: Diagnostics.number(mqtt.maximum_bytes)},
            {label: "协议解析错误", value: Diagnostics.number(mqtt.decode_errors)},
            {label: "最近解析错误", value: typeof mqtt.last_decode_error === "string" ? mqtt.last_decode_error || "尚无错误记录" : "—", detail: true},
            {label: "本地提交消息", value: Diagnostics.number(mqtt.publish_submitted)},
            {label: "传输接口拒绝", value: Diagnostics.number(mqtt.publish_rejected)},
            {label: "提交载荷字节", value: Diagnostics.number(mqtt.publish_bytes)},
            {label: "最近尝试主题", value: mqtt.last_publish_topic || "尚无发布尝试", detail: true},
            {label: "最近尝试时间", value: mqtt.last_publish_at || "—", detail: true},
            {label: "最近接口错误", value: typeof mqtt.last_publish_error === "string" ? mqtt.last_publish_error || "无" : "—", detail: true},
            {label: "交付边界", value: "QoS 0 · 不保留；本地提交不代表选手端或机器人执行。宿主拒绝见操作记录。", detail: true}]},
        {title: "UDP 接收 / 图像交付", rows: [
            {label: "图传状态", value: video?.status ?? "—", detail: true},
            {label: "UDP 已绑定", value: Diagnostics.boolean(videoDetails.bound, "是", "否")},
            {label: "接收端口", value: Diagnostics.number(videoDetails.port)},
            {label: "检测编码", value: Diagnostics.codec(videoDetails.detected_codec)},
            {label: "配置编码", value: Diagnostics.codec(videoDetails.configured_codec ?? videoDetails.codec)},
            {label: "图像尺寸", value: Diagnostics.dimensions(videoDetails.decoded_width,videoDetails.decoded_height)},
            {label: "像素格式", value: videoDetails.source_pixel_format || "—"},
            {label: "转换输入范围", value: videoDetails.decoded_width>0
                ? Diagnostics.boolean(videoDetails.source_full_range,"全范围","按有限范围转换") : "—"},
            {label: "接收缓冲请求", value: Diagnostics.kibibytes(videoDetails.socket_receive_buffer_requested_bytes)},
            {label: "接收缓冲系统报告", value: videoDetails.bound === true
                ? Diagnostics.kibibytes(videoDetails.socket_receive_buffer_actual_bytes) : "—"},
            {label: "接收缓冲说明", value: "系统报告可能包含额外开销，不等于可用码流容量或排队时延。", detail: true},
            {label: "收到数据报", value: Diagnostics.number(videoDetails.datagrams)},
            {label: "收到字节", value: Diagnostics.number(videoDetails.bytes)},
            {label: "无效数据报", value: Diagnostics.number(videoDetails.invalid_datagrams)},
            {label: "已组装传输块", value: Diagnostics.number(videoDetails.transport_chunks ?? videoDetails.compressed_frames)},
            {label: "解析访问单元", value: Diagnostics.number(videoDetails.access_units)},
            {label: "已解码帧", value: Diagnostics.number(videoDetails.decoded_frames)},
            {label: "已转换图像", value: Diagnostics.number(videoDetails.converted_frames)},
            {label: "显示侧跳过", value: Diagnostics.number(videoDetails.ui_skipped_frames)},
            {label: "传输断点", value: Diagnostics.number(videoDetails.transport_discontinuities)},
            {label: "关键帧恢复", value: Diagnostics.number(videoDetails.keyframe_recoveries)},
            {label: "损坏帧丢弃", value: Diagnostics.number(videoDetails.corrupt_frames)},
            {label: "空闲图像缓存", value: Diagnostics.number(videoDetails.cached_output_bytes/1048576," MiB",1)},
            {label: "解码器错误", value: Diagnostics.number(videoDetails.decoder_errors)},
            {label: "图像交付速率", value: Diagnostics.number(video?.fps, " FPS", 1)},
            {label: "最近图像年龄", value: Diagnostics.number(videoDetails.last_frame_age_ms, " ms")}]}
    ]
    readonly property var extensionCards: [
        {title: "实验室原始桥接", rows: [
            {label: "服务状态", value: services?.bridgeStatus ?? "—", detail: true},
            {label: "服务启用", value: Diagnostics.boolean(services?.bridgeDetails?.active, "是", "否")},
            {label: "监听端口", value: Diagnostics.number(services?.bridgeDetails?.listen_port)},
            {label: "连接数", value: Diagnostics.number(services?.bridgeDetails?.connections)},
            {label: "输入缓冲字节", value: Diagnostics.number(services?.bridgeDetails?.pending_input_bytes)},
            {label: "输出缓冲字节", value: Diagnostics.number(services?.bridgeDetails?.pending_output_bytes)},
            {label: "已丢弃消息", value: Diagnostics.number(services?.bridgeDetails?.dropped)}]},
        {title: "模型建议", rows: [
            {label: "服务状态", value: services?.decisionStatus ?? "—", detail: true},
            {label: "服务启用", value: Diagnostics.boolean(services?.decisionDetails?.active, "是", "否")},
            {label: "当前模型", value: services?.decisionDetails?.model ?? "—", detail: true},
            {label: "接口类型", value: services?.decisionDetails?.api ?? "—"},
            {label: "任务", value: Diagnostics.boolean(services?.decisionDetails?.busy, "处理中", "空闲")},
            {label: "输入证据", value: Diagnostics.boolean(services?.decisionInputFresh, "有效", "等待新数据")},
            {label: "超时设置", value: Diagnostics.number(services?.decisionDetails?.timeout_ms, " ms")}]},
        {title: "语音播报", rows: [
            {label: "服务状态", value: services?.speechStatus ?? "—", detail: true},
            {label: "服务启用", value: Diagnostics.boolean(services?.speechDetails?.active, "是", "否")},
            {label: "语音引擎", value: services?.speechDetails?.engine ?? "—"},
            {label: "发音人", value: services?.speechDetails?.voice ?? "—"},
            {label: "合成任务", value: Diagnostics.boolean(services?.speechDetails?.busy, "处理中", "空闲")},
            {label: "输出方式", value: Diagnostics.boolean(services?.speechDetails?.playback, "播放音频", "仅合成")},
            {label: "待播报条数", value: Diagnostics.number(services?.speechDetails?.queued)},
            {label: "已丢弃条数", value: Diagnostics.number(services?.speechDetails?.dropped)}]}
    ]

    readonly property var tabTitles: ["状态总览", "链路诊断", "数据与指令", "扩展服务", "插件管理", "操作配置", "赛季规则", "实验插件"]
    property alias formControl: drawing
    function sequence(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length)
            && value.length >= 0 ? Array.from(value) : [];
    }
    function shown(value) { return value === undefined || value === null ? "未提供" : String(value); }
    function stateColor(state) {
        return state === "fresh" || state === "ok" ? drawing.successColor
            : state === "stale" || state === "warning" ? drawing.warningColor
            : state === "busy" ? drawing.busyColor : drawing.mutedColor;
    }
    function naturalHeight(container) {
        return sequence(container?.children).reduce((maximum,item)=>Math.max(maximum,item.implicitHeight),0);
    }
    OperatorServicesForm {
        id: drawing
        anchors.fill: parent
        drawingBackgroundVisible: false
        selectedPage: root.selectedTab
        loadedPages: root.visitedTabs
        tabCount: root.tabTitles.length
        overviewCount: root.overview.length
        linkCount: root.linkCards.length
        groupCount: root.groupEntries.length
        commandCount: root.history.length
        extensionCount: root.extensionCards.length
        pluginCount: 1
        controlCount: 1
        innovationDelegate: Component {
            OperatorInnovationDock { width:drawing.pageWidth; visible:root.selectedTab===7 }
        }
        linkMaximumHeight: root.naturalHeight(linkContainer)
        extensionMaximumHeight: root.naturalHeight(extensionContainer)
        settingsEnabled: true
        footerText: root.previewOnly ? "离线绘制样例 · 未启动网络、模型或语音服务"
            : root.selectedTab === 1 ? "图像年龄不是端到端延迟；图像缓存仅统计空闲输出缓冲。"
            : root.selectedTab === 2 ? "本地提交结果与服务器执行结果分别判断。" : "状态由当前插件提供 · Esc 返回"
        tabDelegate: Component {
            OperatorButton {
                required property int index
                objectName: "servicesTab_" + index
                width: drawing.tabDelegateWidth
                height: drawing.tabHeight
                text: root.tabTitles[index] ?? "未提供页签"
                primary: root.selectedTab === index
                textColor: drawing.textColor
                font.family: drawing.fontFamily
                font.pixelSize: Math.max(drawing.inputSize,9.5/Math.max(0.1,hudScale))
                onClicked: {
                    if (index === 6) root.seasonRequested();
                    else { root.selectedTab = index; drawing.pagesControl.contentItem.contentY = 0; }
                }
            }
        }
        overviewDelegate: Component {
            OperatorDiagnosticCard {
                required property int index
                readonly property var entry: root.overview[index] ?? ({})
                width: drawing.overviewWidth
                title: root.shown(entry.title)
                status: root.shown(entry.status)
                state: entry.state ?? "unknown"
                stateColor: root.stateColor(state)
                rows: entry.rows ?? []
                minimumCardHeight: drawing.cardMinimumHeight
                bodyTop: drawing.sectionBodyTop; contentMargin: drawing.sectionContentMargin; titleSize: drawing.sectionTitleSize
                fontFamily: drawing.fontFamily; titleColor: drawing.textColor; outlineColor: drawing.sectionBorderColor; surfaceColor: drawing.sectionSurfaceColor
                statusHeight: drawing.cardStatusHeight; statusSize: drawing.cardStatusSize
                rowsTop: drawing.cardRowsTop; rowHeight: drawing.cardRowHeight
                labelSize: drawing.labelSize; valueSize: drawing.valueSize
                numericFontFamily: drawing.numberFamily; textColor: drawing.textColor; mutedColor: drawing.mutedColor
            }
        }
        linkDelegate: Component {
            OperatorDiagnosticTable {
                required property int index
                readonly property var entry: root.linkCards[index] ?? ({})
                width: drawing.linkWidth
                height: drawing.linkColumns > 1 ? drawing.linkMaximumHeight : implicitHeight
                title: root.shown(entry.title); rows: entry.rows ?? []
                bodyTop: drawing.sectionBodyTop; contentMargin: drawing.sectionContentMargin; titleSize: drawing.sectionTitleSize
                fontFamily: drawing.fontFamily; titleColor: drawing.textColor; outlineColor: drawing.sectionBorderColor; surfaceColor: drawing.sectionSurfaceColor
                labelSize: drawing.labelSize; valueSize: drawing.valueSize; rowHeight: drawing.tableRowHeight
                detailMinimumHeight: drawing.tableDetailMinimumHeight; labelHeight: drawing.tableLabelHeight
                detailValueTop: drawing.tableDetailValueTop; detailBottomPadding: drawing.tableDetailBottomPadding
                labelFraction: drawing.tableLabelFraction; valueLeftFraction: drawing.tableValueLeftFraction
                numericFontFamily: drawing.numberFamily; textColor: drawing.textColor; mutedColor: drawing.mutedColor; separatorColor: drawing.lineColor
            }
        }
        groupDelegate: Component {
            OperatorServiceGroupRowForm {
                required property int index
                readonly property var entry: root.groupEntries[index] ?? ({})
                width: drawing.groupDelegateWidth
                titleText: root.shown(entry.title)
                stateText: Diagnostics.stateName(entry.state)
                stateColor: root.stateColor(entry.state)
                detailText: entry.oldFields > 0 ? "含 " + entry.oldFields + " 个旧字段" : ""
                rowHeight: drawing.groupRowHeight; titleSize: drawing.groupTitleSize; detailSize: drawing.noteSize
                fontFamily: drawing.fontFamily; textColor: drawing.textColor; warningColor: drawing.warningColor; separatorColor: drawing.lineColor
            }
        }
        commandDelegate: Component {
            OperatorServiceCommandRowForm {
                required property int index
                readonly property var entry: root.history[index] ?? ({})
                width: drawing.commandDelegateWidth
                titleText: Format.command(entry.topic)
                resultText: Diagnostics.commandResult(entry)
                resultColor: entry.accepted === true ? drawing.successColor : drawing.warningColor
                timeText: "#" + Diagnostics.number(entry.sequence) + " · " + Diagnostics.commandTime(entry)
                reasonText: entry.accepted === true ? "已交给本地发送接口，执行状态以官方选手端回传为准。" : entry.reason || "未提供原因"
                minimumHeight: drawing.commandMinimumHeight; titleSize: drawing.commandTitleSize; noteSize: drawing.noteSize
                fontFamily: drawing.fontFamily; textColor: drawing.textColor; mutedColor: drawing.mutedColor; separatorColor: drawing.lineColor
            }
        }
        extensionDelegate: Component {
            OperatorDiagnosticTable {
                required property int index
                readonly property var entry: root.extensionCards[index] ?? ({})
                width: drawing.extensionWidth
                height: drawing.extensionColumns > 1 ? drawing.extensionMaximumHeight : implicitHeight
                title: root.shown(entry.title); rows: entry.rows ?? []
                bodyTop: drawing.sectionBodyTop; contentMargin: drawing.sectionContentMargin; titleSize: drawing.sectionTitleSize
                fontFamily: drawing.fontFamily; titleColor: drawing.textColor; outlineColor: drawing.sectionBorderColor; surfaceColor: drawing.sectionSurfaceColor
                labelSize: drawing.labelSize; valueSize: drawing.valueSize; rowHeight: drawing.tableRowHeight
                detailMinimumHeight: drawing.tableDetailMinimumHeight; labelHeight: drawing.tableLabelHeight
                detailValueTop: drawing.tableDetailValueTop; detailBottomPadding: drawing.tableDetailBottomPadding
                labelFraction: drawing.tableLabelFraction; valueLeftFraction: drawing.tableValueLeftFraction
                numericFontFamily: drawing.numberFamily; textColor: drawing.textColor; mutedColor: drawing.mutedColor; separatorColor: drawing.lineColor
            }
        }
        pluginDelegate: Component {
            Column {
                width: drawing.pageWidth
                spacing: drawing.rowGap
                OperatorPluginManager {
                    mapRenderer:root.mapRenderer
                    width: parent.width
                    onModelConfigurationRequested: root.providerRequested()
                    onSpeechPanelRequested: root.speechRequested()
                    runtime: root.services?.pluginRuntime ?? null
                    previewOnly: root.previewOnly
                }
                OperatorPluginPackages {
                    width: parent.width
                    visible: !!root.services?.packageRuntime
                    runtime: root.services?.packageRuntime ?? null
                    onOpenExtensionPanelRequested: (packageId,panelId)=>root.openExtensionPanelRequested(packageId,panelId)
                }
            }
        }
        controlDelegate: Component {
            OperatorControlSetup {
                width: drawing.pageWidth
                runtime: root.services?.operatorPreferences ?? null
                previewOnly: root.previewOnly
            }
        }
    }
    Connections { target: drawing.settingsControl; function onClicked() { root.settingsRequested(); } }
}
