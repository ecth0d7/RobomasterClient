import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import "OperatorData.js" as Data
import "OperatorAssetGeometry.js" as Geometry
import "OperatorRosterData.js" as RosterData

Item {
    id: root
    property var telemetry: null
    property int clientID: 0
    property bool blue: false
    property bool previewOnly: false
    property var projectionItems: []
    property double drawingNow: Date.now()
    // 可替换的本地显示刻度，不声称官方协议固定100HP／格。
    property real healthPointsPerCell: 100
    onProjectionItemsChanged: drawingNow=Date.now()
    onVisibleChanged: if (visible) drawingNow=Date.now()
    Timer { interval:500;repeat:true;running:root.visible && Array.isArray(root.projectionItems) && root.projectionItems.length>0;onTriggered:root.drawingNow=Date.now() }
    // 槽位含空中机器人，但它的下方是弹量，不套用不存在的全局空中HP。
    readonly property var roles: blue ? [1, 2, 3, 4, 6, 7] : [7, 6, 4, 3, 2, 1]
    property string assetDirectory: "../resources/player/top_robots/"
    readonly property string teamPrefix: blue ? "blue" : "red"
    implicitWidth: 600
    implicitHeight: 100
    width: implicitWidth
    height: implicitHeight
    property real slotGap: 8

    Row {
        anchors.fill: parent
        spacing: root.slotGap
        Repeater {
            model: root.roles
            Item {
                id: slot
                objectName: "rosterRobot" + robotID
                required property int modelData
                readonly property int robotID: modelData + (root.blue ? 100 : 0)
                readonly property var robot: root.telemetry?.robotData?.[String(robotID)] ?? ({})
                readonly property var projection: RosterData.item(root.projectionItems,robotID,root.drawingNow,root.previewOnly)
                readonly property bool unregistered:projection?.operator_registered_state==="fresh" && projection.operator_registered===false
                readonly property var nativePenalty:robotID===root.clientID
                    && Data.state(root.telemetry,"penalty","penalty_type")==="fresh"
                    && !(Data.state(root.telemetry,"penalty","total_penalty_num")==="fresh"
                        && Data.notOlderThan(root.telemetry,"penalty","total_penalty_num","penalty_type")
                        && root.telemetry.penalty.total_penalty_num===0) ? root.telemetry.penalty : null
                readonly property bool expelled:!unregistered && (nativePenalty?.penalty_type===3
                    || projection?.expelled_state==="fresh" && projection.expelled===true)
                readonly property bool yellowCard:!unregistered && !expelled && ([1,2].includes(nativePenalty?.penalty_type)
                    || projection?.yellow_card_state==="fresh" && projection.yellow_card===true)
                readonly property bool invulnerable:!unregistered && !expelled && !defeated
                    && projection?.respawn_invulnerable_state==="fresh" && projection.respawn_invulnerable===true
                readonly property bool runeActive:!unregistered && !expelled && !defeated
                    && projection?.rune_active_state==="fresh" && projection.rune_active===true
                readonly property var airSupportStatus:modelData!==6 ? undefined : robotID===root.clientID
                    && Data.state(root.telemetry,"airSupport","airsupport_status")==="fresh" ? root.telemetry.airSupport.airsupport_status
                    : projection?.air_support_status_state==="fresh" ? projection.air_support_status : undefined
                readonly property var airShooterStatus:modelData!==6 ? undefined : robotID===root.clientID
                    && Data.state(root.telemetry,"airSupport","shooter_status")==="fresh" ? root.telemetry.airSupport.shooter_status
                    : projection?.air_shooter_status_state==="fresh" ? projection.air_shooter_status : undefined
                readonly property bool airStateKnown:modelData===6 && [0,1].includes(airSupportStatus)
                    && [0,1,2].includes(airShooterStatus)
                readonly property bool airBlocked:airStateKnown && (airSupportStatus===0 || airShooterStatus!==1)
                readonly property bool airCountered:airStateKnown && airSupportStatus===1 && [0,2].includes(airShooterStatus)
                readonly property string healthState: typeof robot.current_health !== "number"
                    || !Number.isFinite(robot.current_health) || robot.current_health < 0 ? "missing"
                    : robot.current_health_source === "robotDynamic" ? Data.state(root.telemetry, "robotDynamic", "current_health")
                    : Data.state(root.telemetry, "globalUnit", "robot_health")
                // 全局生命数组不含空中：身份素材不能因为不存在HP字段就永久变暗。
                readonly property string identityState: modelData === 6
                    ? Data.state(root.telemetry, "globalUnit", "robot_health") : healthState
                readonly property bool defeated: modelData !== 6 && healthState === "fresh" && robot.current_health === 0
                readonly property var linkState: robotID === root.clientID
                    && Data.state(root.telemetry,"robotStatic","connection_state") === "fresh"
                    ? root.telemetry.robotStatic.connection_state
                    : projection?.connection_state_state === "fresh" ? projection.connection_state : undefined
                readonly property var respawnCurrent: robotID === root.clientID
                    && Data.state(root.telemetry,"robotRespawn","current_respawn_progress") === "fresh"
                    ? root.telemetry.robotRespawn.current_respawn_progress
                    : projection?.current_respawn_progress_state === "fresh" ? projection.current_respawn_progress : undefined
                readonly property var respawnTotal: robotID === root.clientID
                    && Data.state(root.telemetry,"robotRespawn","total_respawn_progress") === "fresh"
                    ? root.telemetry.robotRespawn.total_respawn_progress
                    : projection?.total_respawn_progress_state === "fresh" ? projection.total_respawn_progress : undefined
                readonly property bool respawnKnown: defeated && !expelled && !unregistered && Number.isSafeInteger(respawnCurrent)
                    && Number.isSafeInteger(respawnTotal) && respawnTotal > 0
                    && respawnCurrent >= 0 && respawnCurrent <= respawnTotal
                readonly property string avatarKind: ({1: "hero", 2: "engineer", 3: "soldier",
                                                       4: "soldier", 6: "airplane", 7: "soldier"})[modelData] ?? ""
                property real cardScale: width / 409
                property real cardScaleX: width / (root.blue ? 404 : 409)
                property real cardTop: 20
                property real cardHeight: 196 * cardScale
                readonly property var portraitGeometry: Geometry.rosterPortrait(root.teamPrefix, avatarKind)
                readonly property var slotGeometry: Geometry.rosterSlots(root.teamPrefix)
                // 原底板自带血量长槽，不能在贴图下方再画第二条。
                property real healthLeft: slotGeometry.healthX * cardScaleX
                property real healthWidth: slotGeometry.healthWidth * cardScaleX
                readonly property string localLevelState: robotID === root.clientID
                    ? Data.state(root.telemetry,"robotStatic","level") : "missing"
                readonly property var level: localLevelState !== "missing" ? robot.level : projection?.level
                readonly property string levelState: localLevelState !== "missing" ? localLevelState : projection?.level_state ?? "missing"
                readonly property bool levelAvailable: Number.isSafeInteger(level)
                    && level >= 1 && level <= 10 && levelState !== "missing"
                readonly property var levelGeometry: levelAvailable ? Geometry.rosterLevel(level) : null
                readonly property string localMaximumState: robotID === root.clientID
                    ? Data.state(root.telemetry,"robotStatic","max_health") : "missing"
                // GlobalUnitStatus supplies current HP, not other robots’ HP limits.
                readonly property var maximum: localMaximumState === "fresh" ? robot.max_health
                    : projection?.max_health_state === "fresh" ? projection.max_health
                    : localMaximumState !== "missing" ? robot.max_health
                    : projection?.max_health !== undefined ? projection.max_health : undefined
                readonly property string maximumState: localMaximumState === "fresh" ? "fresh"
                    : projection?.max_health_state === "fresh" ? "fresh"
                    : localMaximumState !== "missing" ? localMaximumState
                    : projection?.max_health_state !== undefined ? projection.max_health_state : "missing"
                readonly property bool hasHealthLimit: modelData !== 6 && typeof maximum === "number"
                    && Number.isFinite(maximum) && maximum>0 && maximumState === "fresh"
                readonly property bool healthConflict: healthState === "fresh" && hasHealthLimit && robot.current_health>maximum
                readonly property string localBulletState: robotID === root.clientID
                    ? Data.state(root.telemetry,"robotDynamic","remaining_ammo") : "missing"
                // 己方五槽顺序还需实机核验；UI不把已有推断索引冒充已核验逐机器人弹量。
                readonly property var bullets: localBulletState !== "missing" ? root.telemetry.robotDynamic.remaining_ammo
                    : modelData===6 && projection?.air_ammo_state==="fresh" ? projection.air_ammo
                    : projection?.remaining_bullets !== undefined ? projection.remaining_bullets
                    : (robot.remaining_bullets !== undefined ? robot.remaining_bullets : undefined)
                readonly property string bulletState: localBulletState !== "missing" ? localBulletState
                    : modelData===6 && projection?.air_ammo_state==="fresh" ? "fresh"
                    : projection?.remaining_bullets !== undefined && projection?.remaining_bullets_state !== "missing" ? projection.remaining_bullets_state
                    : (robot.remaining_bullets !== undefined ? Data.state(root.telemetry, "globalUnit", "robot_bullets") : "missing")
                readonly property string bulletExplanation: " · 剩余允许发弹量 " + (bulletState === "missing" ? "未收到已核验逐机器人值" : bullets)
                    + (bulletState === "stale" ? "（旧）" : "")
                readonly property string maximumSourceText: localMaximumState === "fresh" || localMaximumState !== "missing" && projection?.max_health_state !== "fresh"
                    ? "本机接收RobotStaticStatus.max_health" : projection?.max_health !== undefined ? "静态投影 " + projection.source_id : "未接通"
                readonly property string bulletSourceText: localBulletState !== "missing" ? "本机接收RobotDynamicStatus.remaining_ammo"
                    : projection?.remaining_bullets !== undefined ? "逐机器人投影 " + projection.source_id : "未核验映射"
                readonly property bool fillFresh: healthState === "fresh" && maximumState === "fresh"
                readonly property string healthExplanation: (root.blue ? "蓝方" : "红方") + "机器人" + modelData
                    + (unregistered ? " · 未登记出场" : expelled ? " · 红牌罚下" : yellowCard ? " · 黄牌" : "")
                    + (invulnerable ? " · 复活无敌" : "") + (runeActive ? " · 能量机关状态" : "")
                    + (airStateKnown ? airCountered ? " · 雷达反制" : airSupportStatus===1 ? " · 空中支援中" : " · 未呼叫空中支援" : "")
                    + " · 当前血量 " + (healthState === "missing" ? "未收到" : robot.current_health)
                    + (healthState === "stale" ? "（旧）" : "")
                    + (modelData === 6 ? " · 空中不显示HP"
                        : hasHealthLimit ? " · 上限 " + maximum
                                      : maximumState === "stale" ? " · 上限已过期，不绘制百分比"
                                                                  : " · 上限未知，不绘制百分比")
                    + (healthConflict ? " · 血量与上限待核对，不显示有效比例" : "")
                    + " · 本客户端显示刻度 " + root.healthPointsPerCell + "HP/格，非已核实官方规则"
                    + bulletExplanation + (projection ? " · " + projection.source_kind + " · " + projection.source_id
                        + " · " + projection.snapshot_id + " · " + (projection.age_ms/1000).toFixed(1) + "s" : " · 其他静态投影待接")
                    + " · HP源 " + (robot.current_health_source ?? "未收到") + " · 上限源 " + maximumSourceText + " · 弹量源 " + bulletSourceText
                    + (levelAvailable ? " · 等级 " + level + (levelState === "stale" ? "（旧）" : "") : " · 等级未收到")
                Accessible.role: Accessible.StaticText
                Accessible.name: healthExplanation
                HoverHandler { id: healthHover }
                ToolTip.visible: healthHover.hovered
                ToolTip.delay: 450
                ToolTip.text: slot.healthExplanation
                property real displayedHealthFraction: hasHealthLimit && healthState !== "missing"
                                                       && !healthConflict ? Data.fraction(robot.current_health, maximum) : 0
                Behavior on displayedHealthFraction {
                    enabled: slot.fillFresh
                    NumberAnimation { duration: Theme.reducedMotion ? 0 : 240; easing.type: Easing.OutCubic }
                }
                width: (root.width - (root.roles.length - 1) * root.slotGap) / root.roles.length
                height: root.height

                Item {
                    width: parent.width; height: parent.height
                    layer.enabled: slot.defeated || slot.expelled
                    layer.effect: MultiEffect { saturation: -1.0 }
                    opacity: slot.defeated || slot.expelled ? 0.65 : 1
                    // 完整独立底板自带斜槽、编号侧区和血条底座，不裁切大模板。
                    Image {
                        id: background
                        x: 0
                        y: slot.cardTop
                        width: parent.width
                        height: slot.cardHeight
                        source: root.assetDirectory + root.teamPrefix + "_teammate_bg.png"
                        fillMode: Image.Stretch
                        mipmap: true
                        opacity: slot.identityState === "fresh" ? 0.9 : 0.45
                    }
                    Image {
                        // 顶部哨兵按用户确认与步兵共用肖像；其他区域的哨兵照片保持独立。
                        objectName:"rosterPortrait"+slot.robotID
                        // 肖像斜底座与背景主体共用坐标，不按整张图片的中心定位。
                        x: slot.portraitGeometry.x * slot.cardScaleX
                        y: slot.cardTop + slot.portraitGeometry.y * slot.cardScale
                        width: slot.portraitGeometry.width * slot.cardScaleX
                        height: slot.portraitGeometry.height * slot.cardScale
                        source: root.assetDirectory + root.teamPrefix
                                + "_teammate_avatar_" + slot.avatarKind + ".png"
                        fillMode: Image.Stretch
                        mipmap: true
                        opacity: slot.identityState === "fresh" ? 1 : 0.5
                        visible:!slot.unregistered
                    }
                    Item {
                        id: numberSeat
                        // 编号居于底板侧槽的可见主体中心；不能沿整张PNG的边缘定位。
                        x: slot.slotGeometry.numberX * slot.cardScaleX - width / 2
                        y: slot.cardTop + slot.slotGeometry.numberY * slot.cardScale - height / 2
                        width: 25
                        height: 25
                        clip: true
                        OperatorText {
                            id: robotNumber
                            // 原编号红方向左倾、蓝方向右倾：以同一正体字面反向剪切，
                            // 围绕文本基线变形，不能水平镜像成不可读的反字。
                            property real numberShear: root.blue ? -0.25 : 0.25
                            width: parent.width
                            height: 25
                            y: 19 - baselineOffset
                            text: String(slot.modelData)
                            size: 19
                            minimumSize: 0
                            font.family: Theme.rosterNumberFamily
                            font.bold: true
                            font.italic: false
                            font.styleName: "Bold"
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, robotNumber.numberShear, 0, -robotNumber.numberShear * robotNumber.baselineOffset,
                                                    0, 1, 0, 0,
                                                    0, 0, 1, 0,
                                                    0, 0, 0, 1)
                            }
                            style: Text.Normal
                            horizontalAlignment: Text.AlignHCenter
                            color: slot.identityState === "fresh" ? Theme.text : Theme.muted
                        }
                    }
                    Image {
                        id: levelSeat
                        // 按白色字面定位而非透明画布中心，固定底线使新增等级杠向上生长。
                        property real glyphScale: slot.levelGeometry ? 52 / slot.levelGeometry.glyphWidth : 1
                        x: slot.slotGeometry.levelX * slot.cardScaleX
                            - (slot.levelGeometry ? slot.levelGeometry.glyphX + slot.levelGeometry.glyphWidth / 2 : 0) * glyphScale * slot.cardScale
                        y: slot.cardTop + slot.slotGeometry.levelBottom * slot.cardScale
                            - (slot.levelGeometry ? slot.levelGeometry.glyphY + slot.levelGeometry.glyphHeight : 0) * glyphScale * slot.cardScale
                        width: (slot.levelGeometry?.width ?? 0) * glyphScale * slot.cardScale
                        height: (slot.levelGeometry?.height ?? 0) * glyphScale * slot.cardScale
                        source: slot.levelAvailable ? root.assetDirectory + "levels/tab_level_" + slot.level + ".png" : ""
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        visible: slot.levelAvailable && !slot.unregistered
                        layer.enabled:slot.invulnerable || slot.runeActive
                        layer.effect:MultiEffect {colorization:1;colorizationColor:"#e0bc58"}
                        opacity: slot.levelState === "fresh" ? 1 : 0.35
                        Accessible.role: Accessible.StaticText
                        Accessible.name: "机器人" + slot.robotID + "等级" + slot.level + (slot.levelState === "stale" ? "，旧数据" : "")
                    }
                    OperatorText {
                        // 手册地面机器人白字压在头像下沿；空中原图已含名称，不能重复叠字。
                        x: (root.blue ? 95 : 112) * slot.cardScaleX
                        y: slot.cardTop + 158 * slot.cardScale - height
                        width: (root.blue ? 204 : 205) * slot.cardScaleX
                        // 完整容纳15px中文的22px行高，y仍由原底线决定。
                        height: 22
                        visible: slot.modelData !== 6 && !slot.unregistered
                        text: ({1:"英雄",2:"工程",3:"步兵",4:"步兵",7:"哨兵"})[slot.modelData] ?? ""
                        size: 15; minimumSize: 0
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        styleColor: "#e61b2520"
                        color: slot.identityState === "fresh" ? Theme.text : Theme.muted
                        Accessible.ignored: true
                    }
                }
                Image {
                    x: slot.healthLeft + slot.healthWidth / 2 - width / 2
                    y: slot.cardTop - 14
                    width: 28; height: 28
                    source: "../resources/player/tab/message_disconnect.png"
                    visible: slot.linkState === 0 && !slot.defeated && !slot.expelled && !slot.yellowCard && !slot.unregistered
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
                OperatorText {
                    x: slot.healthLeft - 4; y: slot.cardTop - 9
                    width: slot.healthWidth + 8; height: 27
                    text: slot.respawnKnown ? Math.floor(slot.respawnCurrent / slot.respawnTotal * 100) + "%" : ""
                    visible: slot.respawnKnown
                    size: 20; minimumSize: 0; numeric: true; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                OperatorRosterBadge {
                    objectName:"rosterBadge"+slot.robotID
                    x:slot.healthLeft+slot.healthWidth/2-width/2
                    y:slot.cardTop-14
                    kind:slot.expelled ? "expelled" : "yellow"
                    visible:slot.expelled || slot.yellowCard && !slot.defeated
                }
                Canvas {
                    objectName:"rosterAirTarget"+slot.robotID
                    x:slot.healthLeft+slot.healthWidth/2-14;y:slot.cardTop-14;width:28;height:28
                    visible:slot.airCountered && !slot.unregistered && !slot.expelled && !slot.yellowCard
                    onVisibleChanged:if(visible)requestPaint()
                    onPaint:{
                        const c=getContext("2d");c.reset();c.strokeStyle="#8cb8d2";c.lineWidth=1.5;
                        c.beginPath();c.arc(14,14,9,0,Math.PI*2);c.stroke();
                        c.beginPath();c.arc(14,14,3,0,Math.PI*2);c.stroke();
                        for(const p of [[14,0,14,7],[14,21,14,28],[0,14,7,14],[21,14,28,14]]) {
                            c.beginPath();c.moveTo(p[0],p[1]);c.lineTo(p[2],p[3]);c.stroke();
                        }
                    }
                }
                OperatorRosterHealth {
                    id: healthCells
                    objectName: "rosterHealth" + slot.robotID
                    // 按完整底板的现成槽裁区插入斜格，不再画连续矩形条或第二条轨道。
                    x: slot.healthLeft
                    y: slot.cardTop + slot.slotGeometry.healthY * slot.cardScale
                    width: slot.healthWidth
                    height: slot.slotGeometry.healthHeight * slot.cardScale
                    topLeft: slot.slotGeometry.healthTopLeft * slot.cardScaleX
                    topRight: slot.slotGeometry.healthTopRight * slot.cardScaleX
                    bottomLeft: slot.slotGeometry.healthBottomLeft * slot.cardScaleX
                    bottomRight: slot.slotGeometry.healthBottomRight * slot.cardScaleX
                    source: root.assetDirectory + root.teamPrefix + "_tab_bar.png"
                    blue: root.blue
                    defeated: slot.defeated || slot.expelled
                    invulnerable:slot.invulnerable
                    runeActive:slot.runeActive
                    maximum: slot.maximum
                    maximumState: slot.maximumState
                    dataState: slot.healthConflict ? "missing" : slot.healthState
                    pointsPerCell: root.healthPointsPerCell
                    fraction: slot.robot.current_health === 0 || slot.expelled ? 0 : slot.displayedHealthFraction
                    hudScale: Window.window?.ui?.layoutScale ?? 1
                    visible: slot.modelData !== 6 && !slot.unregistered && slot.healthState !== "missing" && slot.maximumState !== "missing" && !slot.healthConflict
                }
                OperatorSlantedFill {
                    // 空中这条槽只表示正在支援，不套用不存在的HP/上限或分格。
                    objectName:"rosterAirSupportBar"+slot.robotID
                    x:healthCells.x;y:healthCells.y;width:healthCells.width;height:healthCells.height
                    source:root.assetDirectory+root.teamPrefix+"_tab_bar.png"
                    sourceClipRect:Qt.rect(0,11,660,2)
                    fraction:1;anchorRight:!root.blue;slantFixedEnd:true
                    slantWidth:Math.abs(healthCells.bottomLeft-healthCells.topLeft)
                    visible:slot.modelData===6 && slot.airSupportStatus===1 && !slot.unregistered && !slot.expelled
                    opacity:.9
                }
                Item {
                    id: ammoSeat
                    objectName: "rosterAmmo" + slot.robotID
                    property real separation: 2
                    property real seatHeight: slot.healthWidth * 48 / 200
                    property real leftSlope: (healthCells.bottomLeft - healthCells.topLeft) / healthCells.height
                    property real rightSlope: (healthCells.bottomRight - healthCells.topRight) / healthCells.height
                    property real leftTop: slot.healthLeft + healthCells.bottomLeft + separation * leftSlope
                    property real rightTop: slot.healthLeft + healthCells.bottomRight + separation * rightSlope
                    property real leftBottom: leftTop + seatHeight * leftSlope
                    property real rightBottom: rightTop + seatHeight * rightSlope
                    property real contentLeft: Math.max(leftTop,leftBottom) - x + 3
                    property real contentRight: Math.min(rightTop,rightBottom) - x - 3
                    // 脱开2逻辑像素后继续两端的原斜线，不能只向下挪导致斜边折断。
                    x: Math.min(leftTop,leftBottom)
                    y: healthCells.y + healthCells.height + separation
                    width: Math.max(rightTop,rightBottom) - x
                    height: seatHeight
                    visible: !slot.unregistered && !slot.expelled && slot.bulletState !== "missing" && Number.isSafeInteger(slot.bullets)
                    clip: true
                    // 手册页03：血槽下面是允许发弹量，不能再把HP数值放这里。
                    OperatorAmmoSlot {
                        anchors.fill: parent
                        blue: root.blue
                        fresh: slot.bulletState === "fresh"
                        topLeft: ammoSeat.leftTop - ammoSeat.x
                        topRight: ammoSeat.rightTop - ammoSeat.x
                        bottomLeft: ammoSeat.leftBottom - ammoSeat.x
                        bottomRight: ammoSeat.rightBottom - ammoSeat.x
                    }
                    OperatorRosterBadge {
                        x:ammoSeat.contentLeft;anchors.verticalCenter:parent.verticalCenter
                        width:10;height:10;kind:"prohibited"
                        visible:slot.modelData===6 && slot.airBlocked
                    }
                    Image {
                        objectName: "rosterAmmoGlyph" + slot.robotID
                        x: ammoSeat.contentLeft+(slot.modelData===6 && slot.airBlocked ? 12 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        width: (slot.modelData===6 ? 10 : 14) * 40 / 41; height: slot.modelData===6 ? 10 : 14
                        source: "../resources/engine-137/sprites/ServerUI_RobotBullets.png"
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        opacity: slot.bulletState === "fresh" ? slot.modelData===6 && slot.airBlocked ? 0.45 : 0.95 : 0.4
                        Accessible.ignored: true
                    }
                    OperatorText {
                        x: ammoSeat.contentLeft + (slot.modelData===6 && slot.airBlocked ? 24 : 17)
                        width: ammoSeat.contentRight - x
                        height: parent.height
                        text: RosterData.compactInteger(slot.bullets) + (slot.bulletState === "stale" ? "旧" : "")
                        numeric: true; size: 15; font.bold: slot.bulletState === "fresh"
                        minimumSize: 0; fontSizeMode: Text.Fit; minimumPixelSize: 9
                        horizontalAlignment: Text.AlignLeft
                        color: slot.bulletState === "fresh" && !(slot.modelData===6 && slot.airBlocked) ? Theme.text : Theme.muted
                    }
                }
            }
        }
    }
}
