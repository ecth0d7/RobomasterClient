import QtQuick
import QtQuick.Controls
import "OperatorBridgeData.js" as Bridge
import "OperatorDiagnostics.js" as Diagnostics
import "OperatorProtocolSchema.js" as Schema
import "UiFormat.js" as Format

OperatorPanelFrame {
    id: root
    property var services: null
    property bool previewOnly: false
    property string selectedSource: ""
    property string selectedGroup: "robotDynamic"
    property int detailTab: 0
    property bool frozen: false
    property var heldPeer: ({})
    property var sourceKeys: []
    property var fieldMetadata: []
    property var groupMetadata: []
    readonly property var details: services?.bridgeDetails ?? ({})
    // 隐藏时停止构建远端列表和序列化显示副本。
    readonly property var peers: visible ? Bridge.object(services?.peers) : ({})
    readonly property var sources: sourceKeys
    readonly property var peer: frozen ? heldPeer : peers[selectedSource] ?? ({})
    readonly property bool hasPeer: Object.keys(peer).length > 0
    readonly property var payload: Bridge.object(peer.payload)
    readonly property var groupEntries: groupMetadata
    readonly property var values: Bridge.object(payload.groups?.[selectedGroup])
    readonly property var fields: hasPeer && detailTab === 1 ? fieldMetadata : []
    readonly property string snapshotJson: visible && hasPeer && detailTab === 2 ? Bridge.json(peer) : ""
    readonly property var summaryRows: [
        {label: "来源标识", value: String(peer.source ?? (selectedSource || "—")), detail: true},
        {label: "报文机器人", value: Diagnostics.number(peer.robot_id), numeric: true},
        {label: "快照客户端", value: Diagnostics.number(payload.client_id), numeric: true},
        {label: "远端比赛链路", value: Diagnostics.boolean(payload.connected, "已连接", "未连接")},
        {label: "本机收到时间 · UTC", value: Bridge.time(peer.received_at_ms), detail: true},
        {label: "远端发送时间 · UTC", value: Bridge.time(peer.sent_at_ms), detail: true}
    ]
    signal layoutRequested
    signal servicesRequested
    title: "实验室互联"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 780
    property alias statusHeight: bridgeForm.statusHeight
    property alias sectionGap: bridgeForm.sectionGap
    property alias sourceWidth: bridgeForm.sourceWidth
    property alias columnGap: bridgeForm.columnGap
    property alias footerHeight: bridgeForm.footerHeight
    property alias footerGap: bridgeForm.footerGap
    property alias footerButtonWidth: bridgeForm.footerButtonWidth
    property alias footerActionsWidth: bridgeForm.footerActionsWidth
    property alias noteSize: bridgeForm.noteSize
    property alias bodySize: bridgeForm.bodySize
    property alias sourceTitleSize: bridgeForm.sourceTitleSize
    property alias statusSurface: bridgeForm.statusSurface
    property alias sourceSurface: bridgeForm.sourceSurface
    property alias selectedSurface: bridgeForm.selectedSurface
    property alias hoverSurface: bridgeForm.hoverSurface
    property alias separatorColor: bridgeForm.separatorColor
    property alias secondaryTextColor: bridgeForm.secondaryTextColor
    OperatorBridgePanelForm {
        id: bridgeForm
        width: parent.width
        height: parent.height
        designSurfaceVisible: false
        bridgeStatusText: root.services?.bridgeStatus ?? "未提供互联服务状态"
        bridgeDetails: root.details
        sourcePresentation: {
            const result = {};
            for (const source of root.sources) {
                const entry = root.peers[source] ?? ({});
                result[source] = {robotTitle: Format.role(entry.robot_id) + " · " + Diagnostics.number(entry.robot_id),
                                  stateText: Bridge.sourceState(entry), fresh: entry.fresh};
            }
            return result;
        }
        sourceItems: root.sources
        selectedSourceKey: root.selectedSource
        selectedGroupKey: root.selectedGroup
        selectedPeer: root.peer
        peerAvailable: root.hasPeer
        peerSummaryRows: root.summaryRows
        groupTitles: root.groupEntries.map(entry => entry.title + " · " + entry.key)
        groupIndex: root.groupEntries.findIndex(entry => entry.key === root.selectedGroup)
        fieldStates: {
            const result = {};
            for (const field of root.fields)
                result[field.name] = Bridge.fieldState(root.peer, root.selectedGroup, field.name, root.values[field.name]);
            return result;
        }
        schemaMessages: Schema.messages
        listenConnectionsText: Diagnostics.number(root.details.listen_port) + " / " + Diagnostics.number(root.details.connections)
        pendingBytesText: Diagnostics.number(root.details.pending_input_bytes) + " / " + Diagnostics.number(root.details.pending_output_bytes) + " B"
        droppedText: "丢弃 " + Diagnostics.number(root.details.dropped)
        peerStateText: root.hasPeer ? (root.frozen ? "固定时：" : "") + Bridge.sourceState(root.peer) + " · 字段状态为远端自报" : "请选择有快照的来源"
        fieldItems: root.fields
        valueItems: root.values
        rawSnapshot: root.snapshotJson
        selectedTab: root.detailTab
        holdingSnapshot: root.frozen
        drawingPreview: root.previewOnly
    }
    onSourcesChanged: if (!frozen && !sources.includes(selectedSource)) selectedSource = sources[0] ?? ""
    onSelectedSourceChanged: { frozen = false; heldPeer = {}; resetScroll(); }
    onSelectedGroupChanged: { refreshFields(); resetScroll(); }
    onValuesChanged: refreshFields()
    onHasPeerChanged: { refreshFields(); refreshGroups(); }
    onPayloadChanged: refreshGroups()
    onPeersChanged: {
        const keys = Object.keys(peers).sort();
        if (JSON.stringify(keys) !== JSON.stringify(sourceKeys)) sourceKeys = keys;
    }
    function refreshFields() {
        const next = hasPeer ? Bridge.fields(selectedGroup, values) : [];
        // 快照数值更新不重建字段控件，保留展开状态与滚动位置。
        if (JSON.stringify(next) !== JSON.stringify(fieldMetadata)) fieldMetadata = next;
    }
    function refreshGroups() {
        const next = hasPeer ? Bridge.groups(payload) : [];
        // 持续快照不刷新相同的下拉模型，避免打断正在选择分组的用户。
        if (JSON.stringify(next) !== JSON.stringify(groupMetadata)) groupMetadata = next;
    }
    function resetScroll() {
        if (bridgeForm.summaryView.contentItem) bridgeForm.summaryView.contentItem.contentY = 0;
        if (bridgeForm.fieldView.contentItem) bridgeForm.fieldView.contentItem.contentY = 0;
        if (bridgeForm.rawView.contentItem) bridgeForm.rawView.contentItem.contentY = 0;
    }
    function toggleFreeze() {
        if (frozen) { frozen = false; heldPeer = {}; if (!sources.includes(selectedSource)) selectedSource = sources[0] ?? ""; }
        else if (hasPeer) { heldPeer = peer; frozen = true; }
    }
    Connections { target: bridgeForm.sourceButtonGroup; function onClicked(button) { root.selectedSource = button.sourceKey; } }
    Connections { target: bridgeForm.summaryControl; function onClicked() { root.detailTab = 0; root.resetScroll(); } }
    Connections { target: bridgeForm.fieldsControl; function onClicked() { root.detailTab = 1; root.resetScroll(); } }
    Connections { target: bridgeForm.rawControl; function onClicked() { root.detailTab = 2; root.resetScroll(); } }
    Connections { target: bridgeForm.freezeControl; function onClicked() { root.toggleFreeze(); } }
    Connections { target: bridgeForm.groupControl; function onActivated(index) { root.selectedGroup = root.groupEntries[index]?.key ?? ""; } }
    Connections { target: bridgeForm.servicesControl; function onClicked() { root.servicesRequested(); } }
    Connections { target: bridgeForm.layoutControl; function onClicked() { root.layoutRequested(); } }
}
