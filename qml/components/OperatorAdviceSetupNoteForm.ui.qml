import QtQuick

// Advice setup text drawing only; content and provenance come from its wrapper.
Item {
    id: root
    implicitWidth: 760
    implicitHeight: note.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property string text: "Designer绘制参考 · 未接通建议宿主。"
    property real size: 12
    property color color: Theme.muted
    property string fontFamily: Theme.fontFamily
    OperatorText {
        id: note
        width: root.width
        height: implicitHeight
        text: root.text
        size: root.size
        color: root.color
        font.family: root.fontFamily
        wrapMode: Text.WrapAnywhere
        elide: Text.ElideNone
    }
}
