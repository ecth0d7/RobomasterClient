import QtQuick
import QtQuick.Layouts

// 实际提供者子区域的绘制；目录、运行选择与刷新在普通QML包装接线。
OperatorSection {
    id: root
    property alias planeControl: planeSelect.selectControl
    property alias providerControl: providerSelect.selectControl
    property alias refreshControl: refreshButton
    property var planeTitles: []
    property var providerTitles: []
    property int planeIndex: -1
    property int providerIndex: -1
    property bool planeEditable: false
    property bool providerEditable: false
    property bool refreshEnabled: false
    property string providerEmptyText: "Designer布局参考 · 原生提供者未接通"
    property string dirtyMessage: ""
    property string lockMessage: "Designer布局参考 · 原生宿主未接通"
    property string unsavedMessage: "尚未保存真实传输配置；本表单不创建数据或启动链路。"
    property var statusRows: [{label: "宿主状态", value: "Designer布局参考 · 未接通", detail: true}]
    property real formSpacing: 12
    property real columnGap: 12
    property real breakpoint: 760
    property real labelHeight: 26
    property real labelGap: 4
    property real fieldSpacing: 8
    property real hintGap: 8
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real refreshWidth: 210
    property real controlHeight: 38
    property real labelSize: 12
    property real noteSize: 12
    property real inputSize: 14
    property color textColor: Theme.text
    property color labelColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property string inputFontFamily: root.fontFamily
    surfaceColor: Theme.hudSolid
    title: "独立平面与传输提供者"
    width: 1300
    height: providerForm.implicitHeight + root.bodyTop + root.contentMargin

    Column {
        id: providerForm
        parent: root.sectionBody
        width: parent.width
        spacing: root.formSpacing
        GridLayout {
            width: parent.width
            columns: width >= root.breakpoint ? 2 : 1
            columnSpacing: root.columnGap
            rowSpacing: root.fieldSpacing
            OperatorSetupSelectForm {
                id: planeSelect
                selectControl.objectName: "terminalLinkPlaneSelect"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                label: "独立链路平面"
                choices: root.planeTitles
                selectedIndex: root.planeIndex
                selectionText: root.planeIndex >= 0 && root.planeIndex < root.planeTitles.length ? root.planeTitles[root.planeIndex] : "明确选择独立链路平面"
                editable: root.planeEditable
                fieldSpacing: root.fieldSpacing
                labelHeight: root.labelHeight
                labelGap: root.labelGap
                controlHeight: root.controlHeight
                hintGap: root.hintGap
                minimumHintHeight: root.minimumHintHeight
                hintBottomPadding: root.hintBottomPadding
                labelSize: root.labelSize
                noteSize: root.noteSize
                inputSize: root.inputSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                mutedColor: root.labelColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
            OperatorSetupSelectForm {
                id: providerSelect
                selectControl.objectName: "terminalLinkProviderSelect"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                label: "已发现的传输提供者"
                choices: root.providerTitles
                selectedIndex: root.providerIndex
                selectionText: root.providerIndex >= 0 && root.providerIndex < root.providerTitles.length ? root.providerTitles[root.providerIndex] : root.providerEmptyText
                editable: root.providerEditable
                fieldSpacing: root.fieldSpacing
                labelHeight: root.labelHeight
                labelGap: root.labelGap
                controlHeight: root.controlHeight
                hintGap: root.hintGap
                minimumHintHeight: root.minimumHintHeight
                hintBottomPadding: root.hintBottomPadding
                labelSize: root.labelSize
                noteSize: root.noteSize
                inputSize: root.inputSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                mutedColor: root.labelColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
        }
        OperatorButton {
            id: refreshButton
            objectName: "terminalLinkRefreshModules"
            width: Math.min(root.refreshWidth, parent.width)
            height: root.controlHeight
            text: "刷新传输提供者目录"
            enabled: root.refreshEnabled
            font.family: root.fontFamily
            textColor: root.textColor
        }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.dirtyMessage.length > 0; text: root.dirtyMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.lockMessage.length > 0; text: root.lockMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.unsavedMessage.length > 0; text: root.unsavedMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorDiagnosticTable {
            width: parent.width
            title: "选择、持久化与当前提供者"
            rows: root.statusRows
            fontFamily: root.fontFamily
            titleSize: root.titleSize
            titleColor: root.titleColor
            textColor: root.textColor
            mutedColor: root.labelColor
            separatorColor: root.separatorColor
            outlineColor: root.separatorColor
            labelSize: root.noteSize
            valueSize: root.inputSize
            contentMargin: root.contentMargin
            bodyTop: root.bodyTop
        }
    }
}
