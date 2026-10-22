import QtQuick

// Historical 2026 performance drawing. Eligibility, choices and submission stay
// in the ordinary wrapper; opening this Form does not choose or submit a value.
Item {
    id: root
    objectName: "performanceSelectorForm"
    implicitWidth: 320
    implicitHeight: root.sectionHeight - root.sectionBodyTop - root.sectionContentMargin
    width: implicitWidth
    height: implicitHeight
    property alias shooterControl: shooterSelect
    property alias chassisControl: chassisSelect
    property alias sentryControl: sentrySelect
    property alias submitControl: submitButton
    property string sectionTitle: "性能 / 控制方式"
    property real sectionHeight: 492
    property real sectionBodyTop: 47
    property real sectionContentMargin: 14
    property real sectionTitleTop: 9
    property real sectionTitleHeight: 25
    property real sectionTitleSize: 14
    property bool compact: false
    property int readingCount: 0
    property var readingTexts: []
    property var readingStale: []
    property var shooterTitles: []
    property var chassisTitles: []
    property var sentryTitles: []
    property int shooterIndex: -1
    property int chassisIndex: -1
    property int sentryIndex: -1
    property string shooterDisplayText: "尚未选择 · 保持当前"
    property string chassisDisplayText: "尚未选择 · 保持当前"
    property string sentryDisplayText: "尚未选择 · 保持当前"
    property bool shooterEditable: false
    property bool chassisEditable: false
    property bool sentryEditable: false
    property bool sentryVisible: false
    property bool submitEnabled: false
    property string statusText: "性能宿主未接通；没有提交选择。"
    property bool statusWarning: true
    property string submitText: "提交性能选择"
    property string historicalText: "选择后提交，生效状态以接收数据为准。"
    property real entrySpacing: 12
    property real readingSpacing: 4
    property real labelHeight: 24
    property real readingHeight: 24
    property real historicalMinimumHeight: 28
    property real controlHeight: 38
    property real statusMinimumHeight: 44
    property real contentFooterGap: 8
    property real statusButtonGap: 10
    property real bottomGap: 4
    property real separatorHeight: 1
    property real scrollContentInset: 16
    property real scrollBarWidth: 8
    property real scrollThumbWidth: 6
    property real scrollRadius: 3
    property real noteSize: 11
    property real readingSize: 12
    property real inputSize: 12
    property real buttonSize: 14
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily
    property bool drawingBackgroundVisible: true
    property color drawingBackgroundColor: Theme.hudSolid
    property color surfaceColor: "transparent"
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color selectSurfaceColor: "#282f2c"
    property color scrollTrackColor: "#14201a"

    Rectangle { anchors.fill: parent; visible: root.drawingBackgroundVisible; color: root.drawingBackgroundColor; z: -1 }
    OperatorScrollableColumn {
        id: selectionBody
        width: parent.width
        height: Math.max(0, statusLabel.y - root.contentFooterGap)
        entrySpacing: root.entrySpacing
        contentRightInset: root.scrollContentInset
        scrollBarWidth: root.scrollBarWidth
        scrollThumbWidth: root.scrollThumbWidth
        scrollRadius: root.scrollRadius
        scrollTrackColor: root.scrollTrackColor
        scrollThumbColor: root.mutedColor
        scrollPressedColor: root.textColor
        OperatorText {
            width: parent.width; height: root.labelHeight
            visible: !root.compact
            text: "当前性能"
            size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily
        }
        Column {
            width: parent.width
            spacing: root.readingSpacing
            Repeater {
                model: root.readingCount
                OperatorText {
                    required property int index
                    width: parent.width; height: root.readingHeight
                    text: root.readingTexts[index] || "—"
                    size: root.readingSize
                    color: root.readingStale[index] ? root.warningColor : root.textColor
                    font.family: root.fontFamily
                }
            }
        }
        OperatorText {
            width: parent.width
            visible: !root.compact
            height: visible ? Math.max(root.historicalMinimumHeight, implicitHeight) : 0
            text: root.historicalText
            size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily
            wrapMode: Text.Wrap; elide: Text.ElideNone
        }
        Rectangle { width: parent.width; height: root.separatorHeight; color: root.separatorColor }
        OperatorText { width: parent.width; height: root.labelHeight; text: "发射机构 · 待提交"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
        OperatorSelect {
            id: shooterSelect
            width: parent.width; height: root.controlHeight
            label: "发射机构性能体系"
            model: root.shooterTitles; currentIndex: root.shooterIndex
            displayText: root.shooterDisplayText; emptyText: root.shooterDisplayText
            enabled: root.shooterEditable
            textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
            font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
        OperatorText { width: parent.width; height: root.labelHeight; text: "底盘体系 · 待提交"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
        OperatorSelect {
            id: chassisSelect
            width: parent.width; height: root.controlHeight
            label: "底盘性能体系"
            model: root.chassisTitles; currentIndex: root.chassisIndex
            displayText: root.chassisDisplayText; emptyText: root.chassisDisplayText
            enabled: root.chassisEditable
            textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
            font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
        OperatorText { width: parent.width; height: root.labelHeight; text: "哨兵控制 · 待提交"; visible: root.sentryVisible; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
        OperatorSelect {
            id: sentrySelect
            width: parent.width; height: root.controlHeight
            label: "哨兵控制方式"
            visible: root.sentryVisible
            model: root.sentryTitles; currentIndex: root.sentryIndex
            displayText: root.sentryDisplayText; emptyText: root.sentryDisplayText
            enabled: root.sentryEditable
            textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
            font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
    }
    OperatorText {
        id: statusLabel
        y: submitButton.y - root.statusButtonGap - height
        width: parent.width
        height: Math.max(root.statusMinimumHeight, implicitHeight)
        text: root.statusText
        wrapMode: Text.Wrap; elide: Text.ElideNone
        size: root.noteSize; color: root.statusWarning ? root.warningColor : root.mutedColor
        font.family: root.fontFamily
    }
    OperatorButton {
        id: submitButton
        y: parent.height - height - root.bottomGap
        width: parent.width; height: root.controlHeight
        text: root.submitText; primary: true; enabled: root.submitEnabled
        textColor: root.textColor; font.family: root.fontFamily
        font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale))
    }
}
