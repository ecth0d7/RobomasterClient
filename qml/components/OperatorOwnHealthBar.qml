import QtQuick

// 仅本机HP的严格显示；绘制属性不改变遥测字段、逐字段时效或补间策略。
OperatorOwnHealthBarForm {
    id: root
    drawingBackgroundVisible: false
    property var display:({present:false,ratio:0,ratioState:"none",identity:"",text:"",marker:"",tone:"muted",description:""})
    lowHealth: root.display.ratio > 0 && root.display.ratio <= 0.2
    backgroundOpacity: root.display.ratioState === "live" ? 0.9 : root.display.present ? 0.45 : 0.22
    fillFraction: motion.fraction
    fillVisible: root.display.ratioState !== "none" && root.display.ratio > 0 && motion.fraction > 0
    fillOpacity: root.display.ratioState === "live" ? 0.9 : 0.35
    readingVisible: root.display.present
    readingText: root.display.text
    readingColor: Theme[root.display.tone]
    markerVisible: root.display.present && root.display.marker.length > 0
    markerText: root.display.marker
    markerColor: root.display.warning ? Theme.warning : Theme.muted
    Accessible.role: Accessible.StaticText
    Accessible.name: display.description
    OperatorFractionMotion {id:motion;display:root.display;duration:240}
    HoverHandler {id:hover}
    OperatorDataToolTip {visible:hover.hovered;text:root.display.description}
}
