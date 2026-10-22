import QtQuick
import QtQuick.Controls
import "UiFormat.js" as Format
import "OperatorAirSupportData.js" as Support
import "OperatorData.js" as Data

Button {
    id: root
    property int clientID: 0
    property bool shortcutsAvailable: false
    property string shortcutLabel: "H"
    property string endShortcutLabel: "N"
    property var telemetry: null
    property bool connectedToPlayer: false
    property bool previewOnly: false
    property bool airSupportSecondsVerified: false
    property bool endShortcutAvailable: false
    readonly property bool aerial: [6,106].includes(clientID)
    readonly property bool remoteRole: [1,3,4,5].includes(clientID % 100)
    readonly property bool roleSupported: [1,2,3,4,5,6].includes(clientID % 100)
    readonly property bool remoteEligible: connectedToPlayer
        && Data.state(telemetry,"robotStatic","robot_id") === "fresh" && telemetry.robotStatic.robot_id === clientID
        && Data.state(telemetry,"robotStatic","alive_state") === "fresh" && telemetry.robotStatic.alive_state === 1
        && (Data.state(telemetry,"robotDynamic","can_remote_heal") === "fresh" && telemetry.robotDynamic.can_remote_heal === true
            || Data.state(telemetry,"robotDynamic","can_remote_ammo") === "fresh" && telemetry.robotDynamic.can_remote_ammo === true)
    readonly property bool actionAvailable: roleSupported && (!remoteRole || remoteEligible)
    readonly property var air: Support.view(telemetry,clientID,connectedToPlayer,airSupportSecondsVerified,previewOnly)
    readonly property string panelTitle: clientID % 100 === 2 ? "工程装配" : clientID % 100 === 6 ? "空中支援" : "远程兑换"
    objectName: "exchangeHint"
    implicitWidth: aerial ? 220 : 266
    implicitHeight: aerial ? 128 : 64
    states: State {
        name: "aerial"
        when: root.aerial
        PropertyChanges { target: root; padding: 0 }
    }
    opacity: 1
    Accessible.name: "查看" + panelTitle + "，只打开面板，不请求动作"+(aerial ? "。"+air.description : "")
    background: Rectangle {
        color: root.hovered && root.enabled ? Theme.hudHover : Theme.hudSurface
        OperatorOutline { color: root.activeFocus ? Theme.green : Theme.hudBorder; emphasized: root.activeFocus }
    }
    contentItem: Item {
        Item {
            anchors.fill: parent
            visible: root.aerial
            BorderImage {
                border {left:12;right:12;top:12;bottom:12}
                visible: !root.air.active
                x:(parent.width-width)/2;y:18;width:Math.max(34,Math.min(112,shortcutMetrics.width+14));height:34
                // 两张都是52×52原键帽底，不含H；0免费余量不禁用打开入口。
                source:"../resources/player/my_robot/airplane_statusbar_h_"
                    +(root.enabled && root.shortcutsAvailable ? "bg" : "unable")+".png"
                OperatorText {anchors.fill:parent;text:root.shortcutsAvailable ? root.shortcutLabel : "—";size:14;font.family:Theme.keyFontFamily;horizontalAlignment:Text.AlignHCenter}
            }
            OperatorText {
                x:10;y:59;width:parent.width-20;height:24
                visible:!root.air.active
                text:root.air.freeText;size:12
                horizontalAlignment:Text.AlignHCenter
                color:root.air.eligible && root.air.fields.left_time.state === "fresh" ? Theme.text : Theme.muted
            }
            OperatorText {
                visible:root.air.active
                y:7;width:parent.width;height:28;text:"空中支援中"
                size:19;font.bold:true;horizontalAlignment:Text.AlignHCenter
            }
            OperatorText {
                visible:root.air.active
                x:8;y:36;width:parent.width-16;height:24;text:root.air.freeText
                size:11;color:Theme.muted;horizontalAlignment:Text.AlignHCenter
            }
            OperatorText {
                visible:root.air.active
                x:8;y:62;width:parent.width-16;height:24;text:root.air.coinsText
                size:11;color:Theme.muted;horizontalAlignment:Text.AlignHCenter
            }
            Rectangle {
                y:96;width:parent.width;height:32
                color:root.hovered && root.enabled ? Theme.hudHover : "transparent"
                OperatorOutline {color:root.activeFocus ? Theme.green : Theme.hudBorder}
                OperatorText {
                    x:6;width:parent.width-12;height:parent.height
                    text:root.air.active && root.endShortcutAvailable ? root.shortcutLabel+" 查看详情 · "+root.endShortcutLabel+" 选择结束"
                        : root.shortcutsAvailable ? "按 "+root.shortcutLabel+" 打开空中支援面板" : "点击查看空中支援"
                    size:11;horizontalAlignment:Text.AlignHCenter
                }
            }
        }
        Item {
            anchors.fill: parent
            visible: !root.aerial
            Item {
                id: compactKey
                x:8;anchors.verticalCenter:parent.verticalCenter
                width:Math.max(38,Math.min(100,shortcutMetrics.width+16));height:38
                BorderImage {
                    anchors.fill:parent
                    source:"../resources/player/my_robot/airplane_statusbar_h_"
                        +(root.enabled && root.shortcutsAvailable ? "bg" : "unable")+".png"
                    border {left:12;right:12;top:12;bottom:12}
                }
                OperatorText {
                    id:compactKeyText
                    anchors.fill:parent;anchors.margins:4
                    text:root.shortcutsAvailable ? root.shortcutLabel : "—"
                    size:14;font.family:Theme.keyFontFamily;horizontalAlignment:Text.AlignHCenter
                }
            }
            OperatorText {
                x:compactKey.x+compactKey.width+10;y:3
                width:parent.width-x-8;height:parent.height-6
                text:!Format.validLogin(root.clientID) ? "请先选择身份"
                    : !root.remoteRole || root.remoteEligible ? root.panelTitle : "远程兑换\n条件未满足"
                size:12;color:root.enabled ? Theme.text : Theme.muted
                wrapMode:Text.WordWrap;maximumLineCount:2
            }
        }
    }
    TextMetrics {id:shortcutMetrics;text:root.shortcutLabel;font.family:Theme.keyFontFamily;font.pixelSize:Math.max(14,compactKeyText.minimumSize/Math.max(.1,compactKeyText.hudScale))}
    ToolTip.visible: hovered
    ToolTip.delay: 450
    ToolTip.text: aerial ? air.description : panelTitle+(shortcutsAvailable ? " · 按 "+shortcutLabel+" 打开面板" : " · 快捷键尚未接通")
}
