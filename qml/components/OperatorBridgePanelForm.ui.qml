import QtQuick
import QtQuick.Controls

// 实验室只读查看的实际绘制层；列表选择、固定快照和导航由包装层接线。
Item {
    id: root
    property alias sourceButtonGroup: sourceButtons
    property alias summaryControl: summaryButton
    property alias fieldsControl: fieldsButton
    property alias rawControl: rawButton
    property alias freezeControl: freezeButton
    property alias groupControl: groupSelect
    property alias servicesControl: servicesButton
    property alias layoutControl: layoutButton
    property alias summaryView: summaryScroll
    property alias fieldView: fieldScroll
    property alias rawView: rawScroll
    property string bridgeStatusText: "Designer布局参考 · 未提供桥接服务"
    property var bridgeDetails: ({})
    property var sourcePresentation: ({})
    property var sourceItems: []
    property string selectedSourceKey: ""
    property string selectedGroupKey: ""
    property var selectedPeer: ({})
    property bool peerAvailable: false
    property var peerSummaryRows: []
    property var groupTitles: []
    property int groupIndex: -1
    property var fieldStates: ({})
    property var schemaMessages: []
    property string listenConnectionsText: "— / —"
    property string pendingBytesText: "— / — B"
    property string droppedText: "丢弃 —"
    property string peerStateText: "请选择有快照的来源"
    property var fieldItems: []
    property var valueItems: ({})
    property string rawSnapshot: ""
    property int selectedTab: 0
    property bool holdingSnapshot: false
    property bool drawingPreview: true
    property bool designSurfaceVisible: true
    property real statusHeight: 100
    property real sectionGap: 16
    property real sourceWidth: 420
    property real columnGap: 22
    property real footerHeight: 38
    property real footerGap: 12
    property real footerButtonWidth: 196
    property real footerActionsWidth: 2 * root.footerButtonWidth + root.footerGap
    property real noteSize: 11
    property real bodySize: 12
    property real sourceTitleSize: 13
    property color statusSurface: "#202a25"
    property color sourceSurface: "#222c26"
    property color selectedSurface: "#345c4d"
    property color hoverSurface: "#34443b"
    property color separatorColor: Theme.line
    property color secondaryTextColor: Theme.muted
    implicitWidth: 1384
    implicitHeight: 692
    width: 1384
    height: 692

    Rectangle {
        anchors.fill: parent
        color: Theme.hudSolid
        z: -1
        visible: root.designSurfaceVisible
    }
    ButtonGroup {
        id: sourceButtons
        exclusive: false
    }
    Rectangle {
        parent: root
        width: parent.width
        height: root.statusHeight
        color: root.statusSurface
        border.color: root.separatorColor
        OperatorText {
            x: 14
            y: 8
            width: 330
            height: 24
            text: "桥接服务"
            size: root.noteSize
            color: root.secondaryTextColor
        }
        OperatorText {
            x: 14
            y: 36
            width: 330
            height: 54
            text: root.bridgeStatusText
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            size: 14
        }
        OperatorText {
            x: 368
            y: 8
            width: parent.width - 670
            height: 24
            text: "监听端口 / TCP 连接"
            size: root.noteSize
            color: root.secondaryTextColor
        }
        OperatorText {
            x: 368
            y: 36
            width: parent.width - 670
            height: 26
            text: root.listenConnectionsText
            numeric: true
            size: 17
        }
        OperatorText {
            x: 368
            y: 68
            width: parent.width - 670
            height: 24
            text: "TCP 连接数不等于已收到快照的来源数"
            size: root.noteSize
            color: root.secondaryTextColor
        }
        OperatorText {
            x: parent.width - 272
            y: 8
            width: 258
            height: 24
            text: "待处理缓存 / 丢弃累计"
            size: root.noteSize
            color: root.secondaryTextColor
        }
        OperatorText {
            x: parent.width - 272
            y: 36
            width: 258
            height: 26
            text: root.pendingBytesText
            numeric: true
            size: 15
        }
        OperatorText {
            x: parent.width - 272
            y: 68
            width: 258
            height: 24
            text: root.droppedText
            size: root.noteSize
            color: root.secondaryTextColor
        }
    }
    OperatorSection {
        id: sourceSection
        parent: root
        y: root.statusHeight + root.sectionGap
        width: root.sourceWidth
        height: parent.height - y - root.footerHeight - root.footerGap
        title: "远端来源 · " + root.sourceItems.length
        OperatorText {
            parent: sourceSection.sectionBody
            width: parent.width
            height: 44
            text: "按独立 source 选择；远端内容只读且未核验。"
            wrapMode: Text.WordWrap
            size: root.bodySize
            color: root.secondaryTextColor
        }
        ListView {
            parent: sourceSection.sectionBody
            id: sourceList
            y: 56
            width: parent.width
            height: parent.height - y - 52
            clip: true
            spacing: 8
            model: root.sourceItems
            ScrollBar.vertical: ScrollBar {
                id: sourceBar
                width: 8
                minimumSize: 0.12
                policy: sourceList.contentHeight
                        > sourceList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                background: Rectangle {
                    color: "#14201a"
                    radius: 3
                }
                contentItem: Rectangle {
                    implicitWidth: 6
                    implicitHeight: 40
                    radius: 3
                    color: sourceBar.pressed ? Theme.text : Theme.muted
                    opacity: sourceBar.active ? 0.9 : 0.6
                }
            }
            delegate: Button {
                id: sourceButton
                required property string modelData
                readonly property string sourceKey: modelData
                ButtonGroup.group: sourceButtons
                readonly property var entry: root.sourcePresentation[modelData]
                                             ?? ({})
                width: ListView.view.width - 12
                height: 116
                Accessible.name: "查看远端来源 " + modelData
                contentItem: Item {
                    OperatorText {
                        width: parent.width - 12
                        height: 28
                        text: sourceButton.entry.robotTitle ?? "身份未知"
                        size: root.sourceTitleSize
                        textFormat: Text.PlainText
                    }
                    OperatorText {
                        y: 32
                        width: parent.width - 12
                        height: 42
                        text: sourceButton.modelData
                        size: root.noteSize
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                    }
                    OperatorText {
                        y: 82
                        width: parent.width - 12
                        height: 24
                        text: sourceButton.entry.stateText ?? "接收时效未知"
                        size: root.noteSize
                        color: sourceButton.entry.fresh
                               === true ? Theme.green : sourceButton.entry.fresh
                                          === false ? Theme.warning : Theme.muted
                    }
                }
                background: Rectangle {
                    color: root.selectedSourceKey === sourceButton.modelData ? root.selectedSurface : sourceButton.hovered ? root.hoverSurface : root.sourceSurface
                    border.color: sourceButton.activeFocus ? Theme.green : Theme.line
                }
            }
            OperatorText {
                anchors.fill: parent
                visible: root.sourceItems.length === 0
                text: "尚未收到远端快照\nTCP 已连接也可能没有快照来源"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                size: root.bodySize
                color: root.secondaryTextColor
            }
        }
        OperatorText {
            parent: sourceSection.sectionBody
            y: parent.height - 44
            width: parent.width
            height: 44
            text: "接收新近程度不证明远端字段或测量有效。"
            wrapMode: Text.WordWrap
            size: root.noteSize
            color: root.secondaryTextColor
        }
    }
    OperatorSection {
        id: detailSection
        parent: root
        x: root.sourceWidth + root.columnGap
        y: root.statusHeight + root.sectionGap
        width: parent.width - x
        height: parent.height - y - root.footerHeight - root.footerGap
        title: root.holdingSnapshot ? "固定显示 · 保留当时状态" : "选中来源 · 实时查看"
        Row {
            parent: detailSection.sectionBody
            width: parent.width
            spacing: 12
            OperatorButton {
                width: (parent.width - 36) / 4
                id: summaryButton
                text: "来源摘要"
                primary: root.selectedTab === 0
            }
            OperatorButton {
                width: (parent.width - 36) / 4
                id: fieldsButton
                text: "远端字段"
                primary: root.selectedTab === 1
            }
            OperatorButton {
                width: (parent.width - 36) / 4
                id: rawButton
                text: "原始快照"
                primary: root.selectedTab === 2
            }
            OperatorButton {
                width: (parent.width - 36) / 4
                id: freezeButton
                text: root.holdingSnapshot ? "恢复实时" : "固定查看"
                enabled: root.peerAvailable
            }
        }
        OperatorText {
            parent: detailSection.sectionBody
            y: 48
            width: parent.width
            height: 28
            text: root.peerStateText
            size: root.bodySize
            color: root.selectedPeer.fresh === false ? Theme.warning : Theme.muted
        }
        OperatorScrollableColumn {
            parent: detailSection.sectionBody
            id: summaryScroll
            y: 88
            width: parent.width
            height: parent.height - y
            visible: root.selectedTab === 0 && root.peerAvailable
            OperatorDiagnosticTable {
                width: parent.width
                title: "独立远端快照"
                rows: root.peerSummaryRows
            }
            OperatorText {
                width: parent.width
                height: 70
                text: "时间为两端各自的 UTC 时间，不相减推断网络延迟；远端比赛连接也不代表本机已连接。"
                wrapMode: Text.WordWrap
                size: root.noteSize
                color: root.secondaryTextColor
            }
        }
        Item {
            parent: detailSection.sectionBody
            y: 88
            width: parent.width
            height: parent.height - y
            visible: root.selectedTab === 1 && root.peerAvailable
            OperatorSelect {
                id: groupSelect
                width: parent.width
                label: "远端快照分组"
                model: root.groupTitles
                currentIndex: root.groupIndex
            }
            OperatorScrollableColumn {
                id: fieldScroll
                y: 52
                width: parent.width
                height: parent.height - y
                entrySpacing: 8
                Repeater {
                    model: root.fieldItems
                    OperatorProtocolField {
                        required property var modelData
                        width: parent.width
                        field: modelData
                        value: root.valueItems[modelData.name]
                        fieldState: root.fieldStates[modelData.name]
                                    ?? "unknown"
                        schema: root.schemaMessages
                    }
                }
            }
        }
        ScrollView {
            parent: detailSection.sectionBody
            id: rawScroll
            y: 88
            width: parent.width
            height: parent.height - y
            visible: root.selectedTab === 2 && root.peerAvailable
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            OperatorTextArea {
                width: rawScroll.availableWidth
                readOnly: true
                numeric: true
                label: "选中来源原始快照显示副本"
                text: root.rawSnapshot
            }
        }
        OperatorText {
            parent: detailSection.sectionBody
            y: 88
            width: parent.width
            height: parent.height - y
            visible: !root.peerAvailable
            text: "暂无选中快照\n收到快照后可查看摘要、全部字段和原始内容"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            size: root.sourceTitleSize
            color: root.secondaryTextColor
        }
    }
    OperatorText {
        parent: root
        y: parent.height - root.footerHeight
        width: parent.width - root.footerActionsWidth - root.footerGap
        height: root.footerHeight
        text: root.drawingPreview ? "离线绘制样例 · 不建立 TCP 连接" : "训练实验室 schema1 · 未认证／未加密 · 不进入本机遥测或AI"
        size: root.noteSize
        color: root.secondaryTextColor
    }
    Row {
        parent: root
        x: parent.width - root.footerActionsWidth
        y: parent.height - root.footerHeight
        spacing: 12
        OperatorButton {
            id: servicesButton
            width: root.footerButtonWidth
            text: "服务详情"
        }
        OperatorButton {
            id: layoutButton
            width: root.footerButtonWidth
            text: "返回面板库"
        }
    }
}
