import QtQuick

// 原经验弧只揭示有效推导段；显示view不修改遥测或结算等级。
OperatorExperienceArcForm {
    id: root
    property var display:({present:false,ratio:0,ratioState:"none",identity:"",marker:"",description:"",maximumLevel:false,warning:false})
    present: root.display.present
    backgroundOpacity: root.display.ratioState === "live" || root.display.maximumLevel ? 1 : 0.45
    fillFraction: motion.fraction
    fillVisible: root.display.ratioState !== "none" && root.display.ratio > 0 && motion.fraction > 0
    fillOpacity: root.display.ratioState === "live" ? 1 : 0.35
    markerText: root.display.marker
    markerVisible: markerText.length > 0 && markerText !== "?"
    markerColor: root.display.warning ? Theme.warning : Theme.muted
    Accessible.role: Accessible.StaticText
    Accessible.name: display.description
    OperatorFractionMotion {id:motion;display:root.display;duration:240}
    HoverHandler {id:hover}
    OperatorDataToolTip {visible:hover.hovered;text:root.display.description}
}
