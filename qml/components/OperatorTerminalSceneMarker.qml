import QtQuick

OperatorTerminalSceneMarkerForm {
    id: root
    property var datum: ({})
    property real surfaceWidth: 0
    property real surfaceHeight: 0
    readonly property bool hasPosition: typeof datum.x_norm === "number" && Number.isFinite(datum.x_norm)
        && typeof datum.y_norm === "number" && Number.isFinite(datum.y_norm)
    x: hasPosition ? datum.x_norm * surfaceWidth - anchorX : 0
    y: hasPosition ? datum.y_norm * surfaceHeight - anchorY : 0
    markerVisible: hasPosition
    labelText: datum.label ?? datum.origin?.item_id ?? ""

    // 这里只画宿主已接纳标记的朝向，不生成坐标、朝向或延长有效期。
    Canvas {
        id: heading
        parent: root.headingContainer
        anchors.fill: parent
        visible: root.datum.heading_known === true && typeof root.datum.heading_deg === "number"
            && Number.isFinite(root.datum.heading_deg)
        rotation: (root.datum.heading_deg ?? 0) + 90
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const context = getContext("2d");
            if (!context) return;
            context.reset();
            context.strokeStyle = root.headingColor;
            context.lineWidth = root.headingStrokeWidth;
            const x = width / 2, tip = height / 14, base = height * 13 / 28;
            context.beginPath();
            context.moveTo(x, base);
            context.lineTo(x, tip);
            context.lineTo(x - width / 7, height * 3 / 14);
            context.moveTo(x, tip);
            context.lineTo(x + width / 7, height * 3 / 14);
            context.stroke();
        }
    }
    onHeadingColorChanged: heading.requestPaint()
    onHeadingStrokeWidthChanged: heading.requestPaint()
}
