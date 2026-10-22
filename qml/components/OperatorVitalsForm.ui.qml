import QtQuick

// 左下角使用的实际组合；参考身份只选择素材，不生成生命、能量或经验值。
Item {
    id: root
    property alias portraitControl: portrait
    property alias experienceControl: experience
    property alias levelControl: level
    property alias healthControl: health
    property alias primaryEnergyControl: chassisEnergy
    property alias secondaryEnergyControl: bufferEnergy
    property alias primaryCaptionControl: chassisCaption
    property alias secondaryCaptionControl: bufferCaption
    property alias combatControl: combat
    property alias penaltyControl: penalty
    property alias hintsControl: hints
    property alias airControl: air
    property int clientID: 3
    property bool defeated: false
    property bool showCombatState: true
    property bool showPenaltyBadge: true
    property bool showStateHints: true
    property bool drawingReferenceVisible: true
    property bool drawingBackgroundVisible: true
    property color drawingBackgroundColor: Theme.hudSolid
    Rectangle {
        anchors.fill: parent
        visible: root.drawingBackgroundVisible
        color: root.drawingBackgroundColor
        z: -1
    }
    readonly property bool aerial: root.clientID % 100 === 6
    readonly property bool separateSentryFace: root.clientID % 100 === 7
    readonly property bool emptyFace: root.clientID % 100 < 1
                                      || root.clientID % 100 > 7
    readonly property bool blue: root.clientID > 100
    property real healthHeight: 30
    property real energyHeight: 6
    property real healthEnergyGap: 6
    property real energyGap: 8
    // 保留原灰翼连接关系：素材y73…134对应三条槽及两个间距。
    property real portraitScale: (root.healthHeight + root.healthEnergyGap + 2 * root.energyHeight
                                  + root.energyGap) / (root.wingBottom - root.wingTop)
    property real wingTop: 73
    property real wingBottom: 134
    property real wingRight: 147
    property real wingSlopeX: 34
    property real wingSlopeY: 59
    property real portraitRight: 159 * root.portraitScale
    property real healthTop: root.wingTop * root.portraitScale
    property real airReadoutTop: 36 * root.portraitScale
    property real barLeft: 110 * root.portraitScale
    property real barRight: 420
    property real energyRight: root.barRight - 24
    property real energyTop: root.healthTop + root.healthHeight + root.healthEnergyGap
    property real legendGap: 8
    property real legendWidth: 112
    property real legendHeight: 86
    property real combatHeight: 26
    property real captionHeight: 22
    property real captionSize: 10
    property real hintsGap: 8
    property real hintsHeight: 24
    property real portraitBottom: 147
    property real experienceLeft: 0
    property real experienceTop: 26
    property real levelLeft: 5
    property real levelTop: 1
    property real levelSize: 36
    property real identityLeft: 49
    property real identityTop: 103
    property real identitySize: 44
    property real identityTextSize: 18
    property real penaltyLeft: 0
    property real penaltyTop: 118
    property real airGap: 14
    property real referenceLeft: root.portraitRight + root.airGap
    property real referenceGap: 36
    property real referenceHeight: 28
    property real referenceSize: 11
    property string fontFamily: Theme.fontFamily
    property color referenceColor: Theme.muted
    property url identitySource: "../resources/player/my_robot/"
                                 + (root.blue ? "blue" : "red") + "_statusbar_id_border.png"
    implicitWidth: root.aerial ? root.portraitRight + root.airGap + air.width : root.barRight
                                 + root.legendGap + root.legendWidth
    width: implicitWidth
    // 状态提示保留固定区域；有无数据不推挤头像、条槽或邻近模块。
    implicitHeight: Math.max(root.portraitBottom * root.portraitScale,
                             root.energyTop + root.energyHeight * 2 + root.energyGap,
                             root.aerial ? 0 : hints.y + hints.height)
    height: implicitHeight

    OperatorText {
        x: root.referenceLeft
        y: root.healthTop - root.referenceGap
        width: Math.max(0, root.barRight - root.referenceLeft)
        height: root.referenceHeight
        visible: root.drawingReferenceVisible
        text: "Designer绘制参考 · 未接通遥测"
        color: root.referenceColor
        size: root.referenceSize
        font.family: root.fontFamily
    }
    OperatorRobotPortrait {
        id: portrait
        z: 2
        clientID: root.clientID
        assetScale: root.portraitScale
        defeated: root.defeated
    }
    OperatorExperienceArc {
        id: experience
        objectName: "ownExperienceArc"
        x: root.experienceLeft * root.portraitScale
        y: root.experienceTop * root.portraitScale
        z: 3
        assetScale: root.portraitScale
        blue: root.blue
    }
    OperatorOwnLevelBadge {
        id: level
        objectName: "ownLevelBadge"
        x: root.levelLeft * root.portraitScale
        y: root.levelTop * root.portraitScale
        width: root.levelSize * root.portraitScale
        height: root.levelSize * root.portraitScale
        z: 4
        blue: root.blue
    }
    OperatorOwnHealthBar {
        id: health
        objectName: "ownHealthBar"
        x: root.barLeft
        y: root.healthTop
        width: root.barRight - root.barLeft
        height: root.healthHeight
        // 原灰翼右缘与三个槽的左端共用同一条绝对直线。
        leftInsetTop: Math.max(
                          0,
                          root.wingRight * root.portraitScale - (health.y - root.healthTop)
                          * root.wingSlopeX / root.wingSlopeY - root.barLeft)
        leftInsetBottom: Math.max(
                             0, root.wingRight * root.portraitScale
                             - (health.y + health.height - root.healthTop)
                             * root.wingSlopeX / root.wingSlopeY - root.barLeft)
        visible: !root.aerial
        blue: root.blue
    }
    Item {
        id: identityBadge
        z: 3
        x: root.identityLeft * root.portraitScale
        y: root.identityTop * root.portraitScale
        width: root.identitySize * root.portraitScale
        height: root.identitySize * root.portraitScale
        Image {
            anchors.fill: parent
            source: root.identitySource
            fillMode: Image.PreserveAspectFit
            mipmap: true
            Accessible.ignored: true
        }
        OperatorText {
            anchors.fill: parent
            text: root.clientID > 0 ? root.clientID % 100 : "—"
            numeric: true
            size: root.identityTextSize * root.portraitScale
            font.family: Theme.numberFamily
            horizontalAlignment: Text.AlignHCenter
        }
    }
    OperatorEnergyBar {
        id: chassisEnergy
        objectName: "ownEnergy0"
        x: root.barLeft
        y: root.energyTop
        width: root.energyRight - root.barLeft
        height: root.energyHeight
        leftInsetTop: Math.max(
                          0,
                          root.wingRight * root.portraitScale - (chassisEnergy.y - root.healthTop)
                          * root.wingSlopeX / root.wingSlopeY - root.barLeft)
        leftInsetBottom: Math.max(
                             0, root.wingRight * root.portraitScale
                             - (chassisEnergy.y + chassisEnergy.height - root.healthTop)
                             * root.wingSlopeX / root.wingSlopeY - root.barLeft)
        visible: !root.aerial
    }
    OperatorEnergyBar {
        id: bufferEnergy
        objectName: "ownEnergy1"
        x: root.barLeft
        y: root.energyTop + root.energyHeight + root.energyGap
        width: root.energyRight - root.barLeft
        height: root.energyHeight
        leftInsetTop: Math.max(
                          0,
                          root.wingRight * root.portraitScale - (bufferEnergy.y - root.healthTop)
                          * root.wingSlopeX / root.wingSlopeY - root.barLeft)
        leftInsetBottom: Math.max(
                             0, root.wingRight * root.portraitScale
                             - (bufferEnergy.y + bufferEnergy.height - root.healthTop)
                             * root.wingSlopeX / root.wingSlopeY - root.barLeft)
        visible: !root.aerial
    }
    Item {
        id: legend
        objectName: "ownVitalsLegend"
        x: root.barRight + root.legendGap
        y: root.healthTop + root.healthHeight / 2 - root.combatHeight / 2
        width: root.legendWidth
        height: root.legendHeight
        visible: !root.aerial
        clip: true
        OperatorCombatState {
            id: combat
            objectName: "ownCombatState"
            width: parent.width
            height: root.combatHeight
            visible: root.showCombatState && displayable
        }
        OperatorVitalsEnergyCaption {
            id: chassisCaption
            visible: false
            y: root.energyTop + root.energyHeight / 2 - root.captionHeight / 2 - legend.y
            width: parent.width
            height: root.captionHeight
            captionSize: root.captionSize
        }
        OperatorVitalsEnergyCaption {
            id: bufferCaption
            visible: false
            y: root.energyTop + root.energyHeight + root.energyGap
               + root.energyHeight / 2 - root.captionHeight / 2 - legend.y
            width: parent.width
            height: root.captionHeight
            captionSize: root.captionSize
        }
    }
    OperatorPenaltyBadge {
        id: penalty
        objectName: "ownPenaltyBadge"
        x: root.penaltyLeft * root.portraitScale
        y: root.penaltyTop * root.portraitScale
        z: 4
        assetScale: root.portraitScale
        visible: root.showPenaltyBadge && record !== null
                 && record.active === true
    }
    OperatorOwnStateHints {
        id: hints
        objectName: "ownStateHints"
        x: root.barLeft
        y: root.energyTop + 2 * root.energyHeight + root.energyGap + root.hintsGap
        width: root.barRight - root.barLeft
        height: root.hintsHeight
        visible: root.showStateHints && !root.aerial && ordered.length > 0
    }
    OperatorAirVitals {
        id: air
        objectName: "airVitals"
        x: root.portraitRight + root.airGap
        y: root.airReadoutTop
        visible: root.aerial && displayable
    }
}
