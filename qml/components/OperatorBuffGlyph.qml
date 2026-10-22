import QtQuick

// 原图只截取不含烘焙数值的符号主体；冷却不使用含×2/×3/×5的图。
Item {
    id: root
    property int kind: 0
    property bool negative: false
    property int robotID:0
    property string terrainKind:""
    property string terrainPhase:""
    property alias source: glyphImage.source
    property alias sourceClipRect: glyphImage.sourceClipRect
    property alias fillMode: glyphImage.fillMode
    property color accent: Theme.muted
    property real strokeWidth: 1.8
    property real unknownSize: 22
    readonly property bool hasTexture: glyphImage.source.toString().length > 0
    onAccentChanged: iconCanvas.requestPaint()
    onStrokeWidthChanged: iconCanvas.requestPaint()
    function terrainSource() {
        const left=terrainPhase==="left";
        if(terrainKind==="flyslope")return "buff_2022_fly_"+(left?"cyan":"green")+".png";
        if(terrainKind==="highland")return "buff_2024_fly_gaodi_"+(left?"blue":"green")+".png";
        if(terrainKind==="road")return "buff_2024_fly_gonglu_"+(left?"blue":"green")+".png";
        if(terrainKind==="tunnel")return "buff_2026_tunnel_"+(terrainPhase==="middle"?"b":"ac")+".png";
        return "";
    }
    readonly property var original: kind===7 && terrainSource().length ? [terrainSource(),Qt.rect(0,0,0,0)] : kind === 1 ? robotID%100===1
        ? ["buff_2022_attack15.png",Qt.rect(0,0,67,47)] : ["rune_2023_attack_200.png", Qt.rect(0,0,47,42)]
        : kind === 2 ? negative ? ["debuff_2023_shield_30.png", Qt.rect(14,14,32,29)]
                               : ["buff_2020_shield_50.png", Qt.rect(0,0,55,42)]
        : kind === 3 ? ["buff_2022_cool_UP.png", Qt.rect(0,0,59,38)]
        : kind === 5 ? ["buff_2020_addhp_10.png", Qt.rect(0,0,54,42)]
        : kind === 6 ? ["buff_bullet.png", Qt.rect(0,0,60,60)] : null
    Image {
        id: glyphImage
        anchors.fill: parent
        visible: root.hasTexture
        source: root.original ? "../resources/engine-137/sprites/" + root.original[0] : ""
        sourceClipRect: root.original ? root.original[1] : Qt.rect(0,0,0,0)
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }
    Canvas {
        id: iconCanvas
        anchors.fill: parent
        visible: !root.hasTexture
        onVisibleChanged: requestPaint()
        Connections { target: root; function onKindChanged() { iconCanvas.requestPaint(); } }
        onPaint: {
            const c = getContext("2d"); c.reset(); c.scale(width / 32, height / 32);
            c.strokeStyle = root.accent; c.fillStyle = root.accent; c.lineWidth = root.strokeWidth;
            if (root.kind === 4) {
                c.beginPath(); c.arc(16, 17, 11, Math.PI, 2 * Math.PI); c.stroke();
                c.beginPath(); c.moveTo(16, 17); c.lineTo(23, 10); c.stroke();
                c.fillRect(7, 23, 18, 2);
            } else if (root.kind === 7) {
                c.beginPath(); c.moveTo(8, 28); c.lineTo(8, 5); c.lineTo(25, 5);
                c.lineTo(22, 11); c.lineTo(25, 17); c.lineTo(8, 17); c.stroke();
            }
        }
    }
    OperatorText {
        anchors.fill: parent
        visible: !root.hasTexture && ![1, 2, 3, 4, 5, 6, 7].includes(root.kind)
        text: "?"
        size: root.unknownSize
        horizontalAlignment: Text.AlignHCenter
    }
}
