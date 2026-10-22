import QtQuick
import QtQuick.Window

Text {
    property bool numeric: false
    property real size: 14
    property real minimumSize: 9.5
    property bool scaleWithHud: true
    readonly property real hudScale: scaleWithHud ? Window.window?.ui?.layoutScale ?? 1 : 1
    color: Theme.text
    textFormat: Text.PlainText
    font.family: numeric ? Theme.numberFamily : Theme.fontFamily
    font.pixelSize: Math.max(size, minimumSize / Math.max(0.1, hudScale))
    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    // 视频上只加细描边，不引入旧版的大块卡片底色。
    style: Text.Outline
    styleColor: "#66303531"
}
