import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "OperatorData.js" as Data
import "OperatorMatchData.js" as MatchData
import "OperatorOutpostData.js" as OutpostData

Item {
    id: root
    readonly property bool presentationActive: visible && (!root.Window.window
        || root.Window.window.visible && root.Window.window.visibility !== Window.Minimized)
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool connectedToPlayer: false
    property var outpostRebuildItems: []
    property var outpostDefenseItems: []
    property var baseDefenseItems: []
    property double drawingNow: Date.now()
    onOutpostRebuildItemsChanged: drawingNow = Date.now()
    onOutpostDefenseItemsChanged: drawingNow = Date.now()
    onBaseDefenseItemsChanged: drawingNow = Date.now()
    Timer { interval: 500; repeat: true; running: root.visible && (Array.isArray(root.outpostRebuildItems) && root.outpostRebuildItems.length > 0 || Array.isArray(root.outpostDefenseItems) && root.outpostDefenseItems.length > 0 || Array.isArray(root.baseDefenseItems) && root.baseDefenseItems.length > 0); onTriggered: root.drawingNow = Date.now() }
    readonly property bool blueLogin: clientID > 100
    readonly property var units: telemetry?.globalUnit ?? ({})
    readonly property var matchView: MatchData.view(telemetry, connectedToPlayer)
    readonly property string timerState: matchView.stage_countdown_sec.state
    readonly property bool roundFresh: matchView.current_round.state === "fresh"
                                      && matchView.total_rounds.state === "fresh" && !matchView.roundConflict
    readonly property bool urgent: matchView.urgent
    readonly property real scoreCenterY: 46
    property real healthTop: scoreCenterY - healthHeight / 2
    property real healthHeight: 30
    // 与下方同阵营机器人队列共用跨度，不能分别维护两组长度。
    property real teamSpan: 600
    readonly property real outpostWidth: 128
    readonly property real healthGroupHeight: healthHeight + 22
    implicitWidth: 1552
    implicitHeight: 112
    width: implicitWidth
    height: implicitHeight

    Image {
        objectName: "matchClockPlate"
        anchors.horizontalCenter: parent.horizontalCenter
        width: 260
        height: width * 92 / 408
        source: "../resources/official/比分栏.png"
        fillMode: Image.Stretch
    }
    Item {
        id: roundSeat
        anchors.horizontalCenter: parent.horizontalCenter
        // 七月手册页01：局次位于倒计时原贴图的最上窄栏，不能溢入下方主体。
        // 原图408×92，窄栏约116×14；与完整底板共用缩放，数字仍动态绑定。
        y: 0
        width: 116 * 260 / 408
        height: 14 * 260 / 408
        clip: true
        Accessible.role: Accessible.StaticText
        Accessible.name: MatchData.description(root.matchView,["current_round","total_rounds"],root.connectedToPlayer,root.previewOnly)
        OperatorText {
            anchors.fill: parent
            text: MatchData.roundText(root.matchView)
            numeric: true
            size: 10
            minimumSize: 0
            fontSizeMode: Text.Fit
            // 原窄栏不足9逻辑像素，不能把最小字号锁在9而裁掉字形。
            minimumPixelSize: 6
            style: Text.Normal
            color: root.roundFresh ? Theme.text : Theme.muted
            horizontalAlignment: Text.AlignHCenter
        }
        HoverHandler { id: roundHover }
        ToolTip.visible: roundHover.hovered
        ToolTip.delay: 450
        ToolTip.text: roundSeat.Accessible.name
    }
    OperatorText {
        id: countdownText
        objectName: "matchCountdown"
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: 80
        height: 32
        text:root.matchView.current_stage.state==="fresh" && root.matchView.current_stage.value===5
            ? "—:—" : MatchData.time(root.matchView.stage_countdown_sec)
        numeric: true
        size: 28
        minimumSize: 0
        font.bold: true
        color: root.timerState !== "fresh" ? Theme.muted : root.urgent ? Theme.red : Theme.text
        horizontalAlignment: Text.AlignHCenter
        fontSizeMode: Text.Fit
        minimumPixelSize: 14
        clip: true
        Accessible.role: Accessible.StaticText
        Accessible.name: MatchData.description(root.matchView,["stage_countdown_sec","current_stage","is_paused"],root.connectedToPlayer,root.previewOnly)
        HoverHandler { id: timerHover }
        ToolTip.visible: timerHover.hovered
        ToolTip.delay: 450
        ToolTip.text: countdownText.Accessible.name
        // 等宽数字与固定文本槽，秒数变化不会挤动比分和基地血条。
        SequentialAnimation on opacity {
            running: root.presentationActive && root.urgent && !Theme.reducedMotion
            loops: Animation.Infinite
            onRunningChanged: if (!running) countdownText.opacity = 1
            NumberAnimation { to: 0.45; duration: 350 }
            NumberAnimation { to: 1; duration: 350 }
        }
    }
    OperatorText {
        id: matchCaption
        objectName: "matchStatusCaption"
        anchors.horizontalCenter: parent.horizontalCenter
        // 状态是原面板下方的独立文字行，不盖住底部发光边。两队头像和经济区不随它移动。
        y: 89
        width: 248
        height: 22
        text: root.matchView.caption
        visible: text.length > 0 && (root.matchView.current_stage.value !== 4 || root.matchView.is_paused.value === true)
        size: 11
        clip: true
        color: Theme.muted
        horizontalAlignment: Text.AlignHCenter
        Accessible.role: Accessible.StaticText
        Accessible.name: MatchData.description(root.matchView,MatchData.fields,root.connectedToPlayer,root.previewOnly)
        HoverHandler { id: captionHover }
        ToolTip.visible: captionHover.hovered
        ToolTip.delay: 450
        ToolTip.text: matchCaption.Accessible.name
    }
    Repeater {
        model: [false, true]
        delegate: Item {
            id: side
            required property bool modelData
            readonly property bool blue: modelData
            readonly property string baseKey: blue === root.blueLogin ? "base_health" : "enemy_base_health"
            readonly property string baseStatusKey: blue === root.blueLogin ? "base_status" : "enemy_base_status"
            readonly property string shieldKey: blue === root.blueLogin ? "base_shield" : "enemy_base_shield"
            readonly property string outpostKey: blue === root.blueLogin ? "outpost_health" : "enemy_outpost_health"
            readonly property string outpostStatusKey: blue === root.blueLogin ? "outpost_status" : "enemy_outpost_status"
            readonly property string scoreKey: blue ? "blue_score" : "red_score"
            width: (root.width - 280) / 2
            height: 90
            x: blue ? root.width - width : 0
            readonly property real teamLeft: blue ? width - root.teamSpan : 0
            readonly property var baseDefense: OutpostData.defense(root.baseDefenseItems,root.clientID,blue ? "blue" : "red",root.drawingNow,root.previewOnly)

            Image {
                id: scorePlate
                objectName: side.blue ? "blueMatchScore" : "redMatchScore"
                readonly property var score: root.matchView[side.scoreKey]
                x: side.blue ? -64 : side.width + 8
                // 原图左右框87×56／88×57；保留相对中心，不将斜边拉成71×53。
                y: root.scoreCenterY - height / 2
                width: 59
                height: width * (side.blue ? 57 / 88 : 56 / 87)
                source: "../resources/official/" + (side.blue ? "右比分框.png" : "左比分框.png")
                fillMode: Image.PreserveAspectFit
                Accessible.role: Accessible.StaticText
                Accessible.name: MatchData.description(root.matchView,[side.scoreKey],root.connectedToPlayer,root.previewOnly)
                HoverHandler { id: scoreHover }
                ToolTip.visible: scoreHover.hovered
                ToolTip.delay: 450
                ToolTip.text: scorePlate.Accessible.name
                OperatorText {
                    objectName: side.blue ? "blueScoreValue" : "redScoreValue"
                    x: 12
                    y: 5
                    width: parent.width - 24
                    height: parent.height - 10
                    text: MatchData.text(scorePlate.score)
                    numeric: true
                    size: 22
                    minimumSize: 0
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 12
                    font.bold: true
                    clip: true
                    color: scorePlate.score.state === "fresh" ? Theme.text : Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                }
                OperatorText {
                    // 附注有独立固定行，不能压在多位比分或原框斜边上。
                    x: 0
                    y: parent.height + 1
                    width: parent.width
                    height: 24
                    text: ({stale:"旧",offline:"断连",unverified:"待核",invalid:"异常"})[scorePlate.score.state] ?? ""
                    visible: text.length > 0
                    size: 11
                    clip: true
                    style: Text.Normal
                    color: Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            OperatorHealthBar {
                id: baseBar
                objectName: side.blue ? "blueBaseBar" : "redBaseBar"
                // 两端使用同一斜槽；内端止于队徽中心，圆徽与血槽垂直居中以完整遮住端部。
                x: side.teamLeft + (side.blue ? 30 : root.outpostWidth + 12)
                y: root.healthTop
                width: root.teamSpan - root.outpostWidth - 42
                height: root.healthHeight
                slantedEnds: true
                blue: side.blue
                value: root.units[side.baseKey]
                maximum: 5000
                valueText: Data.text(root.telemetry, "globalUnit", side.baseKey)
                dataState: Data.state(root.telemetry, "globalUnit", side.baseKey)
                statusValue: root.units[side.baseStatusKey]
                statusState: Data.state(root.telemetry, "globalUnit", side.baseStatusKey)
                shieldValue: root.units[side.shieldKey]
                shieldState: Data.state(root.telemetry, "globalUnit", side.shieldKey)
            }
            Item {
                x: baseBar.x + (side.blue ? baseBar.width / 2 : 20)
                y: root.healthTop + root.healthHeight + 4
                width: baseBar.width / 2 - 20
                height: 18
                // 无护盾不留下孤立的小白符号；有实际护盾时只在血条下沿槽内显示。
                visible: baseBar.shieldState !== "missing" && typeof baseBar.shieldValue === "number"
                    && Number.isFinite(baseBar.shieldValue) && baseBar.shieldValue > 0
                Accessible.role: Accessible.StaticText
                Accessible.name: "基地护盾 " + Data.text(root.telemetry, "globalUnit", side.shieldKey)
                    + (baseBar.shieldState === "stale" ? " · 旧" : "")
                OperatorShieldGlyph {
                    x: side.blue ? parent.width - width : 0
                    y: 2; width: 12; height: 14
                    accent: baseBar.shieldState === "fresh" ? Theme.text : Theme.muted
                }
                OperatorText {
                    x: side.blue ? 0 : 20
                    width: parent.width - 20; height: parent.height
                    text: Data.text(root.telemetry, "globalUnit", side.shieldKey)
                        + (baseBar.shieldState === "stale" ? " · 旧" : "")
                    size: 10
                    // 小窗口的全局可读字号可能高于18px原槽，仍须在槽内适配。
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 9
                    color: baseBar.shieldState === "fresh" ? Theme.text : Theme.muted
                    horizontalAlignment: side.blue ? Text.AlignRight : Text.AlignLeft
                }
            }
            OperatorBaseDetailsFrame {
                x: baseBar.x + (side.blue ? 40 : 8)
                y: root.healthTop + root.healthHeight + 3
                width: baseBar.width - 48
                height: 19
                blue: side.blue
                fresh: baseBar.dataState === "fresh"
                z: -1
            }
            Item {
                objectName: side.blue ? "blueBaseDefense" : "redBaseDefense"
                x:baseBar.x+(side.blue ? 52 : baseBar.width-132)
                y:root.healthTop+root.healthHeight+4
                width:80;height:18
                visible:side.baseDefense?.defense_percent_state==="fresh" && side.baseDefense?.state==="fresh"
                    && baseBar.dataState==="fresh" && typeof baseBar.value==="number" && baseBar.value>0
                OperatorShieldGlyph {
                    x:side.blue ? baseDefenseValueText.contentWidth+8 : parent.width-baseDefenseValueText.contentWidth-20
                    y:2;width:12;height:14;accent:Theme.text
                }
                OperatorText {
                    id:baseDefenseValueText
                    x:side.blue ? 0 : 20;width:parent.width-20;height:parent.height
                    text:parent.visible ? side.baseDefense.defense_percent+"%" : ""
                    size:11;numeric:true;horizontalAlignment:side.blue ? Text.AlignLeft : Text.AlignRight
                }
            }
            Image {
                objectName: side.blue ? "blueTeamLogo" : "redTeamLogo"
                x: side.teamLeft + (side.blue ? 0 : root.teamSpan - 60)
                y: root.healthTop + (root.healthHeight - height) / 2
                width: 60
                height: 60
                z: 2
                source: "../resources/player/top_mid/" + (side.blue ? "blue" : "red") + "_team_logo.png"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
            OperatorOutpost {
                objectName: side.blue ? "blueOutpost" : "redOutpost"
                x: side.teamLeft + (side.blue ? root.teamSpan - root.outpostWidth : 0)
                y: root.healthTop
                width: root.outpostWidth
                heightBudget: root.healthGroupHeight
                height: implicitHeight
                blue: side.blue
                value: root.units[side.outpostKey]
                maximum: 1500
                valueText: Data.text(root.telemetry, "globalUnit", side.outpostKey)
                dataState: Data.state(root.telemetry, "globalUnit", side.outpostKey)
                statusValue: root.units[side.outpostStatusKey]
                statusState: Data.state(root.telemetry, "globalUnit", side.outpostStatusKey)
                rebuildProjection: OutpostData.rebuild(root.outpostRebuildItems, root.clientID, side.blue ? "blue" : "red", root.drawingNow, root.previewOnly)
                defenseProjection: OutpostData.defense(root.outpostDefenseItems, root.clientID, side.blue ? "blue" : "red", root.drawingNow, root.previewOnly)
            }
        }
    }
}
