import QtQuick

// 时间轴只控制演出；连接状态来自宿主，不把演出进度当成设备就绪或鉴权结果。
Item {
    id: root
    property real time: 0
    property string connectionStatus: "未连接"
    property string videoStatus: "等待码流"
    readonly property real unit: Math.min(width / 1600, height / 900)
    readonly property color paper: "#e9eae2"
    readonly property color ink: "#182522"
    readonly property color signal: "#acd8b5"
    readonly property color accent: "#d67d42"
    readonly property real scaffold: ease((time - 180) / 800)
    readonly property real reveal: ease((time - 1360) / 700)
    readonly property real titleIn: ease((time - 1800) / 650)
    readonly property real closing: ease((time - 3380) / 420)
    readonly property real phase: Math.min(4, Math.floor(time / 680))

    function ease(value) {
        const v = Math.max(0, Math.min(1, value));
        return 1 - Math.pow(1 - v, 3);
    }
    function resolve(text, progress) {
        const n = Math.floor(text.length * Math.max(0, Math.min(1, progress)));
        return text.substring(0, n) + (n < text.length ? " /" : "");
    }

    Rectangle { anchors.fill: parent; color: root.paper }
    Image {
        x: root.width * .20 - 70 * root.unit * (1 - root.reveal)
        y: -root.height * .08
        width: root.width * .95; height: root.height * 1.2
        source: "../resources/laboratory/boot-relief.svg"
        sourceSize: Qt.size(1600, 1125)
        fillMode: Image.PreserveAspectCrop
        opacity: .27 * root.scaffold
    }
    Image { anchors.fill: parent; source: "../resources/laboratory/boot-grid.svg"; fillMode: Image.Tile; opacity: .8 * root.scaffold }
    Rectangle {
        x: root.width * .59; y: -root.height * .36
        width: root.height * 1.75; height: width; radius: width / 2
        color: "transparent"; border.color: "#2937483d"; border.width: 1
        opacity: root.scaffold
    }
    Rectangle {
        x: root.width * .59 + 18 * root.unit; y: -root.height * .36 + 18 * root.unit
        width: root.height * 1.75 - 36 * root.unit; height: width; radius: width / 2
        color: "transparent"; border.color: "#1637483d"; border.width: 1
        opacity: root.scaffold
    }
    Item {
        anchors.fill: parent
        opacity: root.scaffold
        Rectangle { x: 0; y: root.height * .055; width: root.width; height: 1; color: "#4437483d" }
        Row {
            x: root.width * .055; y: 14 * root.unit
            height: 22 * root.unit; spacing: 12 * root.unit
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6 * root.unit; height: width; color: root.accent }
            OperatorText { height: parent.height; text: "FIELD INTERFACE / 启动演出"; numeric: true; size: 11 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
        }
        Repeater {
            model: 4
            Item {
                required property int index
                x: index % 2 ? root.width * .966 - width : root.width * .025
                y: index < 2 ? root.height * .072 : root.height * .944 - height
                width: 25 * root.unit; height: width
                rotation: [0, 90, 270, 180][index]
                Rectangle { width: parent.width; height: 1; color: root.accent }
                Rectangle { width: 1; height: parent.height; color: root.accent }
            }
        }
        Item {
            x: root.width * .055; y: root.height * .11
            width: root.width * .25; height: 75 * root.unit
            OperatorText { width: parent.width; height: 30 * root.unit; text: "ROBOMASTER / CLIENT"; font.bold: true; size: 19 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
            OperatorText { y: 31 * root.unit; width: parent.width; height: 20 * root.unit; text: "LOCAL TACTICAL WORKSPACE"; numeric: true; size: 10 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
        }
        Rectangle { x: root.width * .055; y: root.height * .245; width: 1; height: root.height * .54; color: "#5537483d" }
        Repeater {
            model: ["场地 / FIELD", "机器人 / ROBOT", "图传 / VIDEO", "态势 / SITUATION", "操作 / CONTROL"]
            Item {
                required property int index
                required property string modelData
                x: root.width * .055; y: root.height * (.245 + index * .135)
                width: root.width * .16; height: 34 * root.unit
                opacity: root.phase >= index ? 1 : .38
                Rectangle { x: -3 * root.unit; width: 7 * root.unit; height: width; color: index === root.phase ? root.accent : root.ink }
                OperatorText { x: 16 * root.unit; y: -9 * root.unit; width: parent.width; height: 26 * root.unit; text: "0" + (index + 1) + "  " + modelData; numeric: true; size: 11 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
                Rectangle { x: 16 * root.unit; y: 19 * root.unit; width: (index === root.phase ? 106 : 54) * root.unit; height: index === root.phase ? 2 : 1; color: index === root.phase ? root.accent : root.ink }
            }
        }
        OperatorText {
            x: root.width * .055; y: root.height * .856
            width: root.width * .24; height: 23 * root.unit
            text: "LOCAL / HUMAN IN CONTROL"; numeric: true; size: 10 * root.unit
            color: root.ink; scaleWithHud: false; style: Text.Normal
        }
        Repeater {
            model: 39
            Rectangle {
                required property int index
                x: root.width * .055 + index * 4 * root.unit; y: root.height * .896
                width: (index % 5 === 0 ? 2 : 1) * root.unit; height: (index % 7 === 0 ? 15 : 22) * root.unit
                color: root.ink; opacity: .7
            }
        }
    }
    Item {
        id: emblem
        x: root.width * (.50 - .215 * root.reveal) - width / 2
        y: root.height * .49 - height / 2
        width: 212 * root.unit; height: width
        scale: .72 + .28 * root.scaffold
        opacity: 1 - root.closing
        Image {
            anchors.fill: parent
            source: "../resources/laboratory/boot-aperture.svg"; sourceSize: Qt.size(440, 440)
            rotation: root.time * .018; opacity: .35
        }
        Item {
            anchors.fill: parent
            rotation: -90 * (1 - root.scaffold)
            Repeater {
                model: 4
                Item {
                    required property int index
                    anchors.fill: parent; rotation: index * 90
                    Rectangle { x: parent.width * .28; y: parent.height * .23; width: parent.width * .26 * root.scaffold; height: 5 * root.unit; color: root.ink }
                    Rectangle { x: parent.width * .23; y: parent.height * .23; width: 5 * root.unit; height: parent.height * .26 * root.scaffold; color: root.ink }
                }
            }
        }
        Rectangle { anchors.centerIn: parent; width: 21 * root.unit; height: width; rotation: 45 + 90 * (1 - root.scaffold); color: root.accent }
        Rectangle { x: parent.width * .98; y: parent.height * .38; width: 2 * root.unit; height: 49 * root.unit; color: root.accent; opacity: root.reveal }
    }
    Item {
        x: root.width * .35; y: root.height * .64
        width: root.width * .40; height: 60 * root.unit
        opacity: root.scaffold * (1 - root.reveal)
        OperatorText { width: parent.width; height: 32 * root.unit; text: root.resolve("战术工作空间", (root.time - 450) / 650); horizontalAlignment: Text.AlignHCenter; size: 27 * root.unit; font.bold: true; color: root.ink; scaleWithHud: false; style: Text.Normal }
        OperatorText { y: 37 * root.unit; width: parent.width; height: 20 * root.unit; text: "FIELD INTERFACE // LOCAL CLIENT"; horizontalAlignment: Text.AlignHCenter; numeric: true; size: 10 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
    }
    Item {
        id: terminal
        x: root.width * .405 + 75 * root.unit * (1 - root.reveal)
        y: root.height * .335
        width: root.width * .49; height: root.height * .367
        opacity: root.reveal * (1 - root.closing)
        Rectangle { anchors.fill: parent; color: "#f3e9eae2"; border.color: "#5537483d" }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                x: index % 2 ? terminal.width - 10 * root.unit : 8 * root.unit
                y: index < 2 ? 8 * root.unit : terminal.height - 10 * root.unit
                width: 3 * root.unit; height: width; radius: width / 2
                color: "transparent"; border.color: "#8837483d"
            }
        }
        Column {
            anchors.fill: parent; anchors.margins: 28 * root.unit; spacing: 8 * root.unit
            OperatorText { width: parent.width; height: 18 * root.unit; text: "TACTICAL WORKSPACE / 操作终端"; numeric: true; size: 11 * root.unit; font.letterSpacing: 2 * root.unit; color: root.accent; scaleWithHud: false; style: Text.Normal }
            Item {
                width: parent.width; height: 74 * root.unit
                Rectangle { anchors.fill: parent; color: root.ink; scale: root.titleIn; transformOrigin: Item.Left }
                OperatorText { anchors.fill: parent; anchors.leftMargin: 14 * root.unit; text: root.resolve("ROBOMASTER", (root.time - 1680) / 640); size: 49 * root.unit; font.bold: true; font.letterSpacing: 3 * root.unit; color: root.paper; scaleWithHud: false; style: Text.Normal }
            }
            OperatorText { width: parent.width; height: 28 * root.unit; text: "观察 · 协作 · 决策"; size: 21 * root.unit; font.bold: true; font.letterSpacing: 5 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
            Rectangle { width: parent.width * root.titleIn; height: 2 * root.unit; color: root.accent }
            Row {
                width: parent.width; height: 58 * root.unit; spacing: 9 * root.unit
                Repeater {
                    model: ["FIELD", "ROBOT", "VIDEO", "SENSE", "INPUT"]
                    Item {
                        id: moduleTile
                        required property int index
                        required property string modelData
                        readonly property real entrance: root.ease((root.time - 2180 - index * 100) / 470)
                        width: (parent.width - parent.spacing * 4) / 5; height: parent.height
                        opacity: entrance
                        transform: Rotation { origin.x: moduleTile.width / 2; origin.y: moduleTile.height; axis.x: 1; axis.y: 0; axis.z: 0; angle: 82 * (1 - moduleTile.entrance) }
                        Rectangle { anchors.fill: parent; color: root.ink }
                        OperatorText { x: 7 * root.unit; y: 3 * root.unit; width: parent.width - 10 * root.unit; height: 13 * root.unit; text: "M / 0" + (index + 1); numeric: true; size: 8 * root.unit; color: "#97a59b"; scaleWithHud: false; minimumSize: 6; style: Text.Normal }
                        OperatorText { x: 7 * root.unit; y: 21 * root.unit; width: parent.width - 10 * root.unit; height: 26 * root.unit; text: modelData; numeric: true; font.bold: true; size: 17 * root.unit; color: root.paper; scaleWithHud: false; style: Text.Normal }
                    }
                }
            }
        }
    }
    Item {
        x: root.width * .705; y: root.height * .12
        width: root.width * .21; height: root.height * .14
        opacity: root.scaffold * (1 - root.closing)
        OperatorText { width: parent.width; height: 21 * root.unit; text: "LIVE / 本次状态"; numeric: true; size: 11 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
        Rectangle { y: 26 * root.unit; width: parent.width; height: 1; color: "#5537483d" }
        OperatorText { y: 35 * root.unit; width: parent.width; height: 30 * root.unit; text: root.connectionStatus; wrapMode: Text.NoWrap; maximumLineCount: 1; size: 11 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
        OperatorText { y: 69 * root.unit; width: parent.width; height: 26 * root.unit; text: "图传 / " + root.videoStatus; size: 11 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
    }
    Item {
        x: root.width * .73; y: root.height * .82
        width: root.width * .20; height: 66 * root.unit
        opacity: root.scaffold
        OperatorText { width: parent.width; height: 23 * root.unit; text: "演出进度 / SEQUENCE"; numeric: true; size: 10 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
        OperatorText { y: -14 * root.unit; anchors.right: parent.right; width: 60 * root.unit; height: 34 * root.unit; text: String(Math.min(100, Math.floor(root.time / 35.5))).padStart(3, "0"); numeric: true; horizontalAlignment: Text.AlignRight; size: 29 * root.unit; color: root.ink; scaleWithHud: false; style: Text.Normal }
        Rectangle { y: 30 * root.unit; width: parent.width; height: 2 * root.unit; color: "#4437483d" }
        Rectangle { y: 30 * root.unit; width: parent.width * Math.min(1, root.time / 3550); height: 2 * root.unit; color: root.accent }
        Repeater {
            model: 27
            Rectangle { required property int index; x: index * parent.width / 26; y: 39 * root.unit; width: 1; height: (index % 5 === 0 ? 9 : 4) * root.unit; color: root.ink; opacity: .6 }
        }
    }
    Rectangle {
        x: -width + root.width * 2.5 * root.ease((root.time - 1000) / 550)
        width: root.width * .20; height: root.height; rotation: 18
        color: "#f7f7ed"; opacity: root.time > 1000 && root.time < 1550 ? .35 : 0
    }
    Rectangle {
        anchors.fill: parent; color: "#101b19"
        opacity: 1 - root.ease(root.time / 300)
    }
}
