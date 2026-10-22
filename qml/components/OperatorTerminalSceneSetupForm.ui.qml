import QtQuick
import QtQuick.Layouts

// 纯绘制入口：提供者、标记和记录都由普通QML包装传入，不创建场景服务。
Item {
    id: root
    objectName: "terminalSceneSetupForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight

    property alias providerControl: providerSelect
    property alias teamControl: teamField.inputControl
    property alias refreshControl: refreshButton
    property alias saveTeamControl: saveTeamButton
    property alias enableControl: enableButton
    property alias stopControl: stopButton
    property var providerTitles: []
    property int providerSelectedIndex: -1
    property string providerEmptyText: "Designer绘制参考 · 原生提供者目录未接通"
    property string teamValue: ""
    property bool configurationEditable: false
    property bool providerEditable: false
    property bool canRefresh: false
    property bool canSaveTeam: false
    property bool canEnable: false
    property bool canStop: false
    property string statusText: "Designer绘制参考 · 没有启用渲染器或接入目标。"
    property bool statusWarning: false
    property string validationMessage: ""
    property var selectionRows: [{label: "原生场景宿主", value: "未接通", detail: true}]
    property var stateRows: [{label: "坐标与时效校验", value: "未接通；没有有效目标", detail: true}]
    property int markerCount: 0
    property int recordCount: 0
    property Component markerDelegate
    property Component recordDelegate
    readonly property real markerSurfaceWidth: field.width
    readonly property real markerSurfaceHeight: field.height
    readonly property real recordDelegateWidth: recordColumn.width

    property real sectionSpacing: 16
    property real formSpacing: 12
    property real columnGap: 16
    property real breakpoint: 820
    property real fieldSpacing: 8
    property real actionSpacing: 12
    property real refreshButtonWidth: 164
    property real saveTeamButtonWidth: 180
    property real enableButtonWidth: 220
    property real stopButtonWidth: 148
    property real controlHeight: 38
    property real labelHeight: 28
    property real labelSize: 13
    property real inputSize: 14
    property real noteSize: 11
    property real statusSize: 13
    property real sectionTitleSize: 14
    property real sectionContentMargin: 14
    property real sectionBodyTop: 47
    property real projectionHeight: 440
    property real projectionTitleInset: 16
    property real projectionTitleTop: 12
    property real projectionTitleHeight: 26
    property real projectionFieldInset: 18
    property real projectionFieldTop: 52
    property real projectionFieldBottom: 20
    property real projectionAspectRatio: 28 / 15
    property int projectionColumns: 7
    property int projectionRows: 3
    property real gridOpacity: 0.25
    property real gridThickness: 1
    property real emptyInset: 20
    property real emptyMinimumHeight: 60
    property color surfaceColor: Theme.hudSolid
    property color projectionColor: Theme.hudSurface
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color outlineColor: Theme.line
    property color markerColor: Theme.green
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: "二维场景与采集接口分开，可替换为后续UE渲染器。28×15米仅为已核实的场地尺寸；坐标原点、轴向、变换必须由原生标定适配器注册。未知或mock坐标只列文字，不画成真实目标。"
            size: root.statusSize
            color: root.mutedColor
            font.family: root.fontFamily
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
        GridLayout {
            width: parent.width
            columns: width >= root.breakpoint ? 2 : 1
            columnSpacing: root.columnGap
            rowSpacing: root.formSpacing
            Column {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: root.fieldSpacing
                OperatorText { width: parent.width; height: root.labelHeight; text: "可用的渲染提供者"; size: root.labelSize; color: root.textColor; font.family: root.fontFamily }
                OperatorSelect {
                    id: providerSelect
                    objectName: "terminalSceneProviderSelect"
                    width: parent.width
                    height: root.controlHeight
                    label: "渲染提供者"
                    model: root.providerTitles
                    currentIndex: root.providerSelectedIndex
                    displayText: root.providerSelectedIndex >= 0 && root.providerSelectedIndex < root.providerTitles.length ? root.providerTitles[root.providerSelectedIndex] : root.providerEmptyText
                    emptyText: root.providerEmptyText
                    enabled: root.providerEditable
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    textColor: root.textColor
                    borderColor: root.outlineColor
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: "选择会保存当前已审阅的提供者身份，不自动启用。包或配置变化后需要重新明确选择；缺失时不替换为其他提供者。"
                    size: root.noteSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }
            OperatorStartupFieldForm {
                id: teamField
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                label: "明确的项目队伍标识"
                value: root.teamValue
                editable: root.configurationEditable
                hint: "与数据源team_id一致，不是官方登录ID。选择后保存此渲染范围。"
                labelSize: root.labelSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                labelHeight: root.labelHeight
                labelGap: root.fieldSpacing / 2
                controlHeight: root.controlHeight
                hintGap: root.fieldSpacing
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
                inputBorderColor: root.outlineColor
                fontFamily: root.fontFamily
                inputFontFamily: root.fontFamily
            }
        }
        Flow {
            width: parent.width
            spacing: root.actionSpacing
            OperatorButton { id: refreshButton; objectName: "terminalSceneRefreshProviders"; width: Math.min(root.refreshButtonWidth, parent.width); height: root.controlHeight; text: "刷新提供者目录"; enabled: root.canRefresh; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: saveTeamButton; objectName: "terminalSceneSaveTeam"; width: Math.min(root.saveTeamButtonWidth, parent.width); height: root.controlHeight; text: "保存渲染范围"; enabled: root.canSaveTeam; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: enableButton; objectName: "terminalSceneEnable"; width: Math.min(root.enableButtonWidth, parent.width); height: root.controlHeight; text: "启用所选渲染器"; primary: true; enabled: root.canEnable; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: stopButton; objectName: "terminalSceneStop"; width: Math.min(root.stopButtonWidth, parent.width); height: root.controlHeight; text: "停用渲染器"; enabled: root.canStop; font.family: root.fontFamily; textColor: root.textColor }
        }
        OperatorText { width: parent.width; height: implicitHeight; text: root.statusText; color: root.statusWarning ? root.warningColor : root.mutedColor; size: root.statusSize; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.validationMessage.length > 0; text: root.validationMessage; color: root.warningColor; size: root.noteSize; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorDiagnosticTable {
            objectName: "terminalSceneSelectionSection"
            width: parent.width
            title: "已保存的渲染选择"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            outlineColor: root.outlineColor
            fontFamily: root.fontFamily
            textColor: root.textColor
            mutedColor: root.mutedColor
            separatorColor: root.outlineColor
            labelSize: root.noteSize
            valueSize: root.inputSize
            rows: root.selectionRows
        }
        OperatorDiagnosticTable {
            objectName: "terminalSceneStateSection"
            width: parent.width
            title: "场景边界与真实状态"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            outlineColor: root.outlineColor
            fontFamily: root.fontFamily
            textColor: root.textColor
            mutedColor: root.mutedColor
            separatorColor: root.outlineColor
            labelSize: root.noteSize
            valueSize: root.inputSize
            rows: root.stateRows
        }
        Rectangle {
            objectName: "terminalSceneProjection"
            width: parent.width
            height: root.projectionHeight
            color: root.projectionColor
            OperatorOutline { color: root.outlineColor }
            OperatorText { x: root.projectionTitleInset; y: root.projectionTitleTop; width: Math.max(0, parent.width - root.projectionTitleInset * 2); height: root.projectionTitleHeight; text: "坐标投影预览 · 非2027赛场贴图"; size: root.sectionTitleSize; color: root.mutedColor; font.family: root.fontFamily }
            Item {
                id: field
                objectName: "terminalSceneProjectionField"
                x: root.projectionFieldInset
                y: root.projectionFieldTop
                width: Math.max(0, Math.min(parent.width - root.projectionFieldInset * 2, (parent.height - root.projectionFieldTop - root.projectionFieldBottom) * Math.max(0.1, root.projectionAspectRatio)))
                height: width / Math.max(0.1, root.projectionAspectRatio)
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: root.gridThickness; border.color: root.outlineColor }
                Repeater {
                    model: Math.max(0, root.projectionColumns - 1)
                    Rectangle { required property int index; x: (index + 1) * field.width / Math.max(1, root.projectionColumns); width: root.gridThickness; height: field.height; color: root.outlineColor; opacity: root.gridOpacity }
                }
                Repeater {
                    model: Math.max(0, root.projectionRows - 1)
                    Rectangle { required property int index; y: (index + 1) * field.height / Math.max(1, root.projectionRows); width: field.width; height: root.gridThickness; color: root.outlineColor; opacity: root.gridOpacity }
                }
                Repeater { model: root.markerCount; delegate: root.markerDelegate }
                OperatorText {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - root.emptyInset * 2)
                    height: Math.max(root.emptyMinimumHeight, implicitHeight)
                    visible: root.markerCount === 0
                    text: "没有已通过坐标与时效边界的目标\n无消息不生成机器人、方向或数值"
                    size: root.sectionTitleSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }
        }
        Column {
            id: recordColumn
            objectName: "terminalSceneRecords"
            width: parent.width
            spacing: root.sectionSpacing
            visible: root.recordCount > 0
            Repeater { model: root.recordCount; delegate: root.recordDelegate }
        }
    }
}
