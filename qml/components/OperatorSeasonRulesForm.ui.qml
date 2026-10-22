import QtQuick
import QtQuick.Layouts

// Rules/roles page drawing. The parent supplies catalog-derived text and
// stable delegates; this Form does not choose or manufacture a rule profile.
Item {
    id: root
    objectName: "seasonRulesForm"
    implicitWidth: 1300
    implicitHeight: rulesLayout.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property string rolesTitle: "规则角色 · 非线路身份映射"
    property string rolesIntroText: "Designer绘制参考 · 尚未接通已核实的赛季角色目录。"
    property string rolesBoundaryText: "没有角色、规则编号或线路身份数据。此Form不推测官方通信映射。"
    property string emptyRolesText: "当前没有已提供的规则角色。"
    property string emptyCapabilitiesText: "当前没有已提供的规则机制条目。"
    property int roleCount: 0
    property Component roleDelegate: null
    property int capabilityCount: 0
    property Component capabilityDelegate: null
    readonly property real roleDelegateWidth: roleColumn.width
    readonly property real capabilityDelegateWidth: capabilityColumn.width
    property real roleColumnWidth: 348
    property real rulesBreakpoint: 760
    property real columnGap: 16
    property real formSpacing: 12
    property real fieldSpacing: 6
    property real introMinimumHeight: 68
    property real boundaryMinimumHeight: 94
    property real contentMargin: 14
    property real bodyTop: 47
    property real titleSize: 14
    property real noteSize: 12
    property real inputSize: 14
    property real boundarySize: 11
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    GridLayout {
        id: rulesLayout
        width: root.width
        columns: width >= root.rulesBreakpoint ? 2 : 1
        columnSpacing: root.columnGap
        rowSpacing: root.formSpacing
        OperatorSection {
            id: rolesSection
            objectName: "seasonRulesRolesSection"
            Layout.fillWidth: rulesLayout.columns === 1
            Layout.minimumWidth: 0
            Layout.preferredWidth: rulesLayout.columns === 2 ? root.roleColumnWidth : 0
            Layout.alignment: Qt.AlignTop
            implicitHeight: roleColumn.implicitHeight + bodyTop + contentMargin
            height: implicitHeight
            title: root.rolesTitle
            contentMargin: root.contentMargin
            bodyTop: root.bodyTop
            titleSize: root.titleSize
            surfaceColor: root.surfaceColor
            titleColor: root.textColor
            outlineColor: root.separatorColor
            fontFamily: root.fontFamily
            Column {
                id: roleColumn
                width: parent.width
                spacing: root.fieldSpacing
                OperatorText {
                    width: parent.width
                    height: Math.max(root.introMinimumHeight, implicitHeight)
                    text: root.rolesIntroText
                    size: root.noteSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    visible: root.roleCount === 0
                    text: root.emptyRolesText
                    size: root.noteSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
                Repeater { model: root.roleCount; delegate: root.roleDelegate }
                OperatorText {
                    width: parent.width
                    height: Math.max(root.boundaryMinimumHeight, implicitHeight)
                    text: root.rolesBoundaryText
                    size: root.boundarySize
                    color: root.warningColor
                    font.family: root.fontFamily
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
            }
        }
        Column {
            id: capabilityColumn
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: root.formSpacing
            OperatorText {
                width: parent.width
                height: implicitHeight
                visible: root.capabilityCount === 0
                text: root.emptyCapabilitiesText
                size: root.noteSize
                color: root.mutedColor
                font.family: root.fontFamily
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
            Repeater { model: root.capabilityCount; delegate: root.capabilityDelegate }
        }
    }
}
