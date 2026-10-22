import QtQuick
import QtQuick.Layouts

// 本地总线的显示与显式按钮。mock生成、清理和观测数据均由行为包装接线。
Item {
    id: root
    objectName: "seasonLocalBusForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias seedControl: seedButton
    property alias clearControl: clearButton
    property string introText: "Designer绘制参考 · 尚未接通原生本地总线，没有自动生成观测。"
    property string statusText: "未提供生产源或输入接纳状态。"
    property string emptyText: "没有本地观测，不补造比赛数值。"
    property bool seedEnabled: false
    property bool clearEnabled: false
    property int observationCount: 0
    property Component observationDelegate: null
    readonly property real observationDelegateWidth: observationsColumn.width
    property real sectionSpacing: 12
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real actionWidth: 240
    property real secondaryActionWidth: 180
    property real columnGap: 12
    property real breakpoint: 760
    property real controlHeight: 38
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
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText { width: parent.width; height: implicitHeight; text: root.introText; size: root.introSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        GridLayout {
            width: parent.width
            columns: width >= root.breakpoint ? 3 : 1
            columnSpacing: root.columnGap
            rowSpacing: root.formSpacing
            OperatorButton { id: seedButton; objectName: "seasonLocalBusSeedMock"; Layout.preferredWidth: root.actionWidth; Layout.fillWidth: parent.width < root.breakpoint; Layout.minimumWidth: 0; Layout.preferredHeight: root.controlHeight; text: "生成本地mock观测"; primary: true; enabled: root.seedEnabled; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: clearButton; objectName: "seasonLocalBusClearMock"; Layout.preferredWidth: root.secondaryActionWidth; Layout.fillWidth: parent.width < root.breakpoint; Layout.minimumWidth: 0; Layout.preferredHeight: root.controlHeight; text: "清空本地演示"; enabled: root.clearEnabled; font.family: root.fontFamily; textColor: root.textColor }
            OperatorText { Layout.fillWidth: true; Layout.minimumWidth: 0; text: root.statusText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.observationCount === 0; text: root.emptyText; size: root.introSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        Column {
            id: observationsColumn
            objectName: "seasonLocalBusObservations"
            width: parent.width
            spacing: root.sectionSpacing
            visible: root.observationCount > 0
            Repeater { model: root.observationCount; delegate: root.observationDelegate }
        }
    }
}
