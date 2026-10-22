import QtQuick
import QtQuick.Layouts

// 手动规则参考的绘制；计算、规则选择和修改意图都留在普通QML包装。
Item {
    id: root
    objectName: "seasonMechanicsForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias healthControl: healthField.inputControl
    property alias outpostsControl: outpostsCheck
    property alias basesControl: basesCheck
    property string introText: "Designer绘制参考 · 原生规则推算未接通，不是实时比赛数据。"
    property string healthValue: ""
    property bool controlEditable: false
    property bool outpostsValue: false
    property bool basesValue: false
    property var logisticsRows: []
    property var territoryRows: []
    property string healthHint: "未提供已核实的推算公式或结果。"
    property string territoryNote: "未读取真实积分，不按本机时钟累计。"
    property string logisticsTitle: "手动后勤推算"
    property string territoryTitle: "手动阵地条件推算"
    property real sectionSpacing: 16
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real columnGap: 16
    property real breakpoint: 880
    property real controlHeight: 38
    property real labelHeight: 26
    property real labelGap: 4
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real contentMargin: 14
    property real bodyTop: 47
    property real sectionTitleSize: 14
    property real introSize: 13
    property real noteSize: 12
    property real inputSize: 14
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText { width: parent.width; height: implicitHeight; text: root.introText; size: root.introSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        GridLayout {
            width: parent.width
            columns: width >= root.breakpoint ? 2 : 1
            columnSpacing: root.columnGap
            rowSpacing: root.sectionSpacing
            OperatorSection {
                id: logisticsSection
                objectName: "seasonMechanicsLogisticsSection"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                implicitHeight: logisticsColumn.implicitHeight + bodyTop + contentMargin
                title: root.logisticsTitle
                contentMargin: root.contentMargin
                bodyTop: root.bodyTop
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                Column {
                    id: logisticsColumn
                    parent: logisticsSection.sectionBody
                    width: parent.width
                    spacing: root.formSpacing
                    OperatorStartupFieldForm {
                        id: healthField
                        inputControl.objectName: "seasonMechanicsReferenceHealth"
                        inputControl.inputMethodHints: Qt.ImhDigitsOnly
                        width: parent.width
                        label: "手动输入基地HP（0–10000）"
                        hint: "仅供规则参考；不是实收遥测，不写入总线。"
                        maximumLength: 5
                        value: root.healthValue
                        editable: root.controlEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        hintGap: root.fieldSpacing
                        minimumHintHeight: root.minimumHintHeight
                        hintBottomPadding: root.hintBottomPadding
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.separatorColor
                    }
                    OperatorDiagnosticTable { width: parent.width; title: "推算结果 · 不包含网络实测"; rows: root.logisticsRows; fontFamily: root.fontFamily; titleSize: root.sectionTitleSize; titleColor: root.textColor; textColor: root.textColor; mutedColor: root.mutedColor; separatorColor: root.separatorColor; outlineColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize; contentMargin: root.contentMargin; bodyTop: root.bodyTop }
                    OperatorText { width: parent.width; height: implicitHeight; text: root.healthHint; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                }
            }
            OperatorSection {
                id: territorySection
                objectName: "seasonMechanicsTerritorySection"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                implicitHeight: territoryColumn.implicitHeight + bodyTop + contentMargin
                title: root.territoryTitle
                contentMargin: root.contentMargin
                bodyTop: root.bodyTop
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                Column {
                    id: territoryColumn
                    parent: territorySection.sectionBody
                    width: parent.width
                    spacing: root.formSpacing
                    OperatorCheckBox { id: outpostsCheck; objectName: "seasonMechanicsReferenceOutposts"; width: parent.width; height: root.controlHeight; text: "手动假设：同时控制两个前哨阵地"; checked: root.outpostsValue; enabled: root.controlEditable; font.family: root.fontFamily; textColor: root.textColor }
                    OperatorCheckBox { id: basesCheck; objectName: "seasonMechanicsReferenceBases"; width: parent.width; height: root.controlHeight; text: "手动假设：同时控制两个基地阵地"; checked: root.basesValue; enabled: root.controlEditable; font.family: root.fontFamily; textColor: root.textColor }
                    OperatorDiagnosticTable { width: parent.width; title: "条件推算 · 非官方积分"; rows: root.territoryRows; fontFamily: root.fontFamily; titleSize: root.sectionTitleSize; titleColor: root.textColor; textColor: root.textColor; mutedColor: root.mutedColor; separatorColor: root.separatorColor; outlineColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize; contentMargin: root.contentMargin; bodyTop: root.bodyTop }
                    OperatorText { width: parent.width; height: implicitHeight; text: root.territoryNote; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                }
            }
        }
    }
}
