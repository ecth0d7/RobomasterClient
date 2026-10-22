import QtQuick

// 两行与鼠标共用绘制；没有输入源时不填造本机按下状态。
Item {
    id: root
    property alias triggerRow: trigger
    property alias controlRow: control
    property alias captureControl: control.captureControl
    property bool sourceDisplayable: false
    property bool heldKeysActive: false
    property bool captureEnabled: false
    property bool captureIntended: false
    property bool mouseKnown: false
    property bool mouseLeftDown: false
    property bool mouseRightDown: false
    property bool mouseMiddleDown: false
    property int mouseMotionX: 0
    property int mouseMotionY: 0
    property int mouseWheelDirection: 0
    property string triggerValue: "—"
    property string controlValue: "—"
    property var keyLabels: []
    property string footerText: "输入源未提供"
    property bool footerWarning: false
    property bool footerVisible: false
    property string explanationText: "未接通本机输入监视源"
    property string fontFamily: Theme.fontFamily
    property string keyFontFamily: Theme.keyFontFamily
    property string keyStyleName: "Condensed"
    property string triggerFontFamily: root.keyFontFamily
    property string triggerStyleName: root.keyStyleName
    property real hudScale: 1
    property real minimumKeySize: 14
    property real minimumLabelSize: 11
    property real physicalTextSize: 10.5
    property real minimumKeyGap: 2
    property real physicalKeyGap: 1.5
    property real minimumLabelWidth: 27
    property real minimumRowHeight: 22
    property real physicalRowHeight: 18
    property real minimumRowGap: 5
    property real physicalRowGap: 3
    property real minimumFooterHeight: 18
    property real metricPadding: 4
    property real footerMetricPadding: 2
    property real measuredKeyHeight: 0
    property real measuredLabelHeight: 0
    property real measuredLabelWidth: 0
    property real keySize: Math.max(root.minimumKeySize,
                                    root.physicalTextSize / Math.max(
                                        0.1, root.hudScale))
    property real labelSize: Math.max(root.minimumLabelSize,
                                      root.physicalTextSize / Math.max(
                                          0.1, root.hudScale))
    property real keyGap: Math.max(root.minimumKeyGap,
                                   root.physicalKeyGap / Math.max(
                                       0.1, root.hudScale))
    property real labelWidth: Math.max(
                                  root.minimumLabelWidth, Math.ceil(
                                      root.measuredLabelWidth) + root.labelGap)
    property real labelGap: 4
    property real rowHeight: Math.max(
                                 root.minimumRowHeight,
                                 root.physicalRowHeight / Math.max(
                                     0.1, root.hudScale),
                                 root.measuredKeyHeight + root.metricPadding,
                                 root.measuredLabelHeight + root.metricPadding)
    property real rowGap: Math.max(root.minimumRowGap,
                                   root.physicalRowGap / Math.max(
                                       0.1, root.hudScale))
    property real topMargin: 3
    property real footerGap: 3
    property real footerTop: root.topMargin + root.rowHeight * 2 + root.rowGap + root.footerGap
    property real footerHeight: Math.max(
                                    root.minimumFooterHeight,
                                    root.measuredLabelHeight + root.footerMetricPadding)
    property real textInset: 4
    property real measuredKeysWidth: 0
    property real minimumWidth: 340
    property real mouseColumnWidth: 51
    property real mouseWidth: 32
    property real mouseHeight: 28
    property real mouseRightMargin: 13
    property real captureWidth: 38
    property real captureHeight: 28
    property real captureRightMargin: 10
    property real borderWidth: 0.7
    property real focusBorderWidth: 1
    property color labelColor: Theme.muted
    property color textColor: Theme.text
    property color warningColor: Theme.warning
    property color idleSurface: "#88323b34"
    property color activeSurface: "#99435345"
    property color idleBorder: "#91afbcb2"
    property color activeBorder: "#a08da994"
    property color focusColor: Theme.green
    implicitWidth: Math.max(
                       root.minimumWidth,
                       root.labelWidth + root.labelGap + root.measuredKeysWidth
                       + 2 * root.textInset + root.mouseColumnWidth)
    implicitHeight: root.footerTop + (root.footerVisible ? root.footerHeight : 0)
    width: root.implicitWidth
    height: root.implicitHeight
    OperatorKeyMonitorRowForm {
        id: trigger
        y: root.topMargin
        width: root.width
        height: root.rowHeight
        labelText: "触发"
        fallbackText: root.sourceDisplayable ? root.triggerValue : "—"
        captureObjectName: "keyMouseTriggerDisplay"
        mouseGlyph.known: root.mouseKnown
        mouseGlyph.leftDown: root.mouseLeftDown
        mouseGlyph.rightDown: root.mouseRightDown
        mouseGlyph.middleDown: root.mouseMiddleDown
        mouseGlyph.motionX: root.mouseMotionX
        mouseGlyph.motionY: root.mouseMotionY
        mouseGlyph.wheelDirection: root.mouseWheelDirection
        fontFamily: root.fontFamily
        keyFontFamily: root.keyFontFamily
        keyStyleName: root.keyStyleName
        fallbackFontFamily: root.triggerFontFamily
        fallbackStyleName: root.triggerStyleName
        keySize: root.keySize
        labelSize: root.labelSize
        keyGap: root.keyGap
        labelWidth: root.labelWidth
        labelGap: root.labelGap
        textInset: root.textInset
        mouseColumnWidth: root.mouseColumnWidth
        mouseWidth: root.mouseWidth
        mouseHeight: root.mouseHeight
        mouseRightMargin: root.mouseRightMargin
        captureWidth: root.captureWidth
        captureHeight: root.captureHeight
        captureRightMargin: root.captureRightMargin
        borderWidth: root.borderWidth
        focusBorderWidth: root.focusBorderWidth
        labelColor: root.labelColor
        textColor: root.textColor
        idleSurface: root.idleSurface
        activeSurface: root.activeSurface
        idleBorder: root.idleBorder
        activeBorder: root.activeBorder
        focusColor: root.focusColor
    }
    OperatorKeyMonitorRowForm {
        id: control
        y: root.topMargin + root.rowHeight + root.rowGap
        width: root.width
        height: root.rowHeight
        labelText: "控制"
        fallbackText: root.sourceDisplayable ? root.controlValue : "—"
        keyLabels: root.keyLabels
        showKeyLabels: true
        heldKeysActive: root.heldKeysActive
        captureVisible: true
        captureEnabled: root.captureEnabled
        captureIntended: root.captureIntended
        captureDescription: root.explanationText
        captureObjectName: "keyMouseCaptureButton"
        mouseGlyph.known: root.mouseKnown
        mouseGlyph.leftDown: root.mouseLeftDown
        mouseGlyph.rightDown: root.mouseRightDown
        mouseGlyph.middleDown: root.mouseMiddleDown
        mouseGlyph.motionX: root.mouseMotionX
        mouseGlyph.motionY: root.mouseMotionY
        mouseGlyph.wheelDirection: root.mouseWheelDirection
        fontFamily: root.fontFamily
        keyFontFamily: root.keyFontFamily
        keyStyleName: root.keyStyleName
        keySize: root.keySize
        labelSize: root.labelSize
        keyGap: root.keyGap
        labelWidth: root.labelWidth
        labelGap: root.labelGap
        textInset: root.textInset
        mouseColumnWidth: root.mouseColumnWidth
        mouseWidth: root.mouseWidth
        mouseHeight: root.mouseHeight
        mouseRightMargin: root.mouseRightMargin
        captureWidth: root.captureWidth
        captureHeight: root.captureHeight
        captureRightMargin: root.captureRightMargin
        borderWidth: root.borderWidth
        focusBorderWidth: root.focusBorderWidth
        labelColor: root.labelColor
        textColor: root.textColor
        idleSurface: root.idleSurface
        activeSurface: root.activeSurface
        idleBorder: root.idleBorder
        activeBorder: root.activeBorder
        focusColor: root.focusColor
    }
    OperatorText {
        visible: root.footerVisible
        x: root.labelWidth + root.labelGap
        y: root.footerTop
        width: Math.max(0, root.width - x)
        height: root.footerHeight
        text: root.footerText
        font.family: root.fontFamily
        size: root.labelSize
        style: Text.Normal
        clip: true
        color: root.footerWarning ? root.warningColor : root.labelColor
    }
}
