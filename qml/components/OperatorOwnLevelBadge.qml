import QtQuick

OperatorOwnLevelBadgeForm {
    id: root
    property var display: ({present: false, showGlyph: false, live: false, invalid: false,
                            warning: false, field: {value: 0}, marker: "", description: "等级来源未提供"})
    present: root.display.present
    glyphVisible: root.display.showGlyph
    live: root.display.live
    invalid: root.display.invalid
    warning: root.display.warning
    // 只有已核对的1…10等级才生成素材URL；未知／异常不加载缺失文件。
    levelValue: root.display.showGlyph ? root.display.field.value : 0
    markerText: root.display.marker
    descriptionText: root.display.description
    HoverHandler { id: hover }
    OperatorDataToolTip { visible: hover.hovered; text: root.display.description }
}
