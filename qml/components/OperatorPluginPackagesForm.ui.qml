import QtQuick
import QtQuick.Layouts

// 可视化管理布局。目录、状态、schema与动作均由普通QML包装接线。
Item {
    id: root
    objectName: "pluginPackagesForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias refreshControl: refreshButton
    property alias installationDirectoryControl: installationDirectoryInput
    property alias installControl: installButton
    property alias saveControl: saveButton
    property alias undoControl: undoButton
    property alias enableControl: enableButton
    property alias disableControl: disableButton
    property alias removalConfirmationControl: removalConfirmationCheck
    property alias removeControl: removeButton
    property Component packageDelegate: null
    property Component fieldDelegate: null
    property Component panelDelegate: null
    property int packageCount: 0
    property int fieldCount: 0
    property int panelCount: 0
    readonly property real packageDelegateWidth: packageList.width
    readonly property real fieldDelegateWidth: configurationColumn.width
    readonly property real panelDelegateWidth: Math.min(root.panelButtonWidth,
                                                        panelFlow.width)
    property bool hasSelection: false
    property bool refreshEnabled: false
    property bool installationDirectoryEditable: false
    property bool installEnabled: false
    property bool saveEnabled: false
    property bool undoEnabled: false
    property bool enableEnabled: false
    property bool disableEnabled: false
    property bool removalConfirmationEnabled: false
    property bool removeEnabled: false
    property bool removalConfirmed: false
    property string installationDirectoryText: ""
    property string introText: "本地插件包可增加服务和面板。安装、配置、启用与依赖就绪分别显示；基础MQTT、图传、输入和本机数据不随某个扩展一起移除。"
    property string statusText: "Designer绘制参考 · 未接通原生插件包宿主，没有安装或运行插件。"
    property string lockText: ""
    property string configFileText: "未接通宿主，尚无管理配置路径"
    property string restorationText: "参数和启用选择会保存。重启仅恢复当前范围内已确认且内容未变的插件；新插件或内容变化后需重新确认。"
    property string emptyPackagesText: "尚无已发现的插件。绘制层不创建模拟包或伪造运行状态。"
    property string configurationIntroText: "字段由当前插件声明。保存由原生宿主再次校验；配置不包含运行验证或机器人权限。修改运行中配置会按宿主生命周期退役旧实例。"
    property string nativeRestartText: ""
    property string configurationReviewText: ""
    property string emptyFieldsText: "此插件没有声明可编辑配置。"
    property string formErrorText: ""
    property string saveText: "保存插件配置"
    property string panelStatusText: "原生插件与依赖就绪后才能打开面板；绘制层不创建面板或数据。"
    property string noPanelsText: "此插件没有声明面板。"
    property string removalText: "先停用当前插件。移除只作用于实例插件目录中的此包，基础服务保持独立；依赖此包能力的其他扩展会等待依赖恢复。"
    property string removalConfirmationText: "确认移除当前本地插件包"
    property var selectionRows: []
    property real sectionSpacing: 16
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real actionSpacing: 12
    property real actionWidth: 190
    property real installButtonWidth: 190
    property real panelButtonWidth: 210
    property real columnGap: 12
    property real installBreakpoint: 700
    property real controlHeight: 38
    property real labelHeight: 24
    property real sectionContentMargin: 14
    property real sectionBodyTop: 47
    property real sectionTitleSize: 14
    property real introSize: 13
    property real noteSize: 12
    property real inputSize: 14
    property real structuredHeight: 136
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color highlightColor: Theme.green
    property string fontFamily: Theme.fontFamily

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        z: -1
    }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: root.introText
            size: root.introSize
            color: root.textColor
            font.family: root.fontFamily
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
        OperatorButton {
            id: refreshButton
            objectName: "packageRefresh"
            width: Math.min(root.actionWidth, parent.width)
            height: root.controlHeight
            text: "刷新插件包目录"
            enabled: root.refreshEnabled
            font.family: root.fontFamily
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: root.lockText.length > 0
            text: root.lockText
            size: root.noteSize
            color: root.warningColor
            font.family: root.fontFamily
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: root.statusText
            size: root.noteSize
            color: root.textColor
            font.family: root.fontFamily
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: "管理配置：" + root.configFileText
            size: root.noteSize
            color: root.secondaryTextColor
            font.family: root.fontFamily
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: root.restorationText
            size: root.noteSize
            color: root.secondaryTextColor
            font.family: root.fontFamily
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
        OperatorSection {
            id: installSection
            objectName: "packageInstallSection"
            width: parent.width
            height: installColumn.implicitHeight + bodyTop + contentMargin
            title: "从本机目录安装"
            titleSize: root.sectionTitleSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: installColumn
                parent: installSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: "选择含rmplugin.json的本机目录。宿主校验后复制到实例插件目录；不执行安装脚本，安装后不会自动启用。插件代码应来自你信任的来源。"
                    size: root.noteSize
                    color: root.secondaryTextColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                OperatorText {
                    width: parent.width
                    height: root.labelHeight
                    text: "本地插件包目录"
                    size: root.noteSize
                    color: root.secondaryTextColor
                    font.family: root.fontFamily
                }
                GridLayout {
                    width: parent.width
                    columns: width >= root.installBreakpoint ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.formSpacing
                    OperatorInput {
                        id: installationDirectoryInput
                        objectName: "packageInstallationDirectory"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: root.controlHeight
                        label: "含rmplugin.json的本机插件包目录"
                        placeholderText: "含rmplugin.json的本机目录"
                        text: root.installationDirectoryText
                        enabled: root.installationDirectoryEditable
                        maximumLength: 4096
                        font.family: root.fontFamily
                        font.pixelSize: Math.max(root.inputSize,
                                                 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorButton {
                        id: installButton
                        objectName: "packageInstall"
                        Layout.preferredWidth: installColumn.width >= root.installBreakpoint ? root.installButtonWidth : -1
                        Layout.fillWidth: installColumn.width < root.installBreakpoint
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: root.controlHeight
                        text: "安装本地插件包"
                        primary: true
                        enabled: root.installEnabled
                        font.family: root.fontFamily
                    }
                }
            }
        }
        OperatorSection {
            id: packagesSection
            objectName: "packageListSection"
            width: parent.width
            height: packageList.implicitHeight + bodyTop + contentMargin
            title: "已发现的插件包 · " + root.packageCount
            titleSize: root.sectionTitleSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: packageList
                parent: packagesSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    visible: root.packageCount === 0
                    text: root.emptyPackagesText
                    size: root.noteSize
                    color: root.secondaryTextColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Repeater {
                    model: root.packageCount
                    delegate: root.packageDelegate
                }
            }
        }
        OperatorDiagnosticTable {
            objectName: "packageDetailsSection"
            visible: root.hasSelection
            width: parent.width
            title: "当前插件 · 实际运行与依赖"
            rows: root.selectionRows
        }
        OperatorSection {
            id: configurationSection
            objectName: "packageConfigurationSection"
            visible: root.hasSelection
            width: parent.width
            height: configurationColumn.implicitHeight + bodyTop + contentMargin
            title: "插件声明的配置"
            titleSize: root.sectionTitleSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: configurationColumn
                parent: configurationSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: root.configurationIntroText
                    size: root.noteSize
                    color: root.secondaryTextColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    visible: root.nativeRestartText.length > 0
                    text: root.nativeRestartText
                    size: root.noteSize
                    color: root.warningColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    visible: root.configurationReviewText.length > 0
                    text: root.configurationReviewText
                    size: root.noteSize
                    color: root.warningColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    visible: root.fieldCount === 0
                    text: root.emptyFieldsText
                    size: root.noteSize
                    color: root.secondaryTextColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Repeater {
                    model: root.fieldCount
                    delegate: root.fieldDelegate
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    visible: root.formErrorText.length > 0
                    text: root.formErrorText
                    size: root.noteSize
                    color: root.warningColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Flow {
                    width: parent.width
                    spacing: root.actionSpacing
                    OperatorButton {
                        id: saveButton
                        objectName: "packageSaveConfiguration"
                        width: Math.min(root.actionWidth, parent.width)
                        height: root.controlHeight
                        text: root.saveText
                        primary: true
                        enabled: root.saveEnabled
                        font.family: root.fontFamily
                    }
                    OperatorButton {
                        id: undoButton
                        objectName: "packageUndoConfiguration"
                        width: Math.min(root.actionWidth, parent.width)
                        height: root.controlHeight
                        text: "撤销未保存修改"
                        enabled: root.undoEnabled
                        font.family: root.fontFamily
                    }
                    OperatorButton {
                        id: enableButton
                        objectName: "packageEnable"
                        width: Math.min(root.actionWidth, parent.width)
                        height: root.controlHeight
                        text: "启用已保存插件"
                        enabled: root.enableEnabled
                        font.family: root.fontFamily
                    }
                    OperatorButton {
                        id: disableButton
                        objectName: "packageDisable"
                        width: Math.min(root.actionWidth, parent.width)
                        height: root.controlHeight
                        text: "停用当前插件"
                        enabled: root.disableEnabled
                        font.family: root.fontFamily
                    }
                }
            }
        }
        OperatorSection {
            id: panelsSection
            objectName: "packagePanelsSection"
            visible: root.hasSelection
            width: parent.width
            height: panelColumn.implicitHeight + bodyTop + contentMargin
            title: "插件提供的面板"
            titleSize: root.sectionTitleSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: panelColumn
                parent: panelsSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: root.panelStatusText
                    size: root.noteSize
                    color: root.secondaryTextColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    visible: root.panelCount === 0
                    text: root.noPanelsText
                    size: root.noteSize
                    color: root.secondaryTextColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Flow {
                    id: panelFlow
                    width: parent.width
                    spacing: root.actionSpacing
                    Repeater {
                        model: root.panelCount
                        delegate: root.panelDelegate
                    }
                }
            }
        }
        OperatorSection {
            id: removalSection
            objectName: "packageRemovalSection"
            visible: root.hasSelection
            width: parent.width
            height: removalColumn.implicitHeight + bodyTop + contentMargin
            title: "移除当前本地插件包"
            titleSize: root.sectionTitleSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: removalColumn
                parent: removalSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: root.removalText
                    size: root.noteSize
                    color: root.secondaryTextColor
                    font.family: root.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                OperatorCheckBox {
                    id: removalConfirmationCheck
                    objectName: "packageRemovalConfirmation"
                    width: parent.width
                    height: root.controlHeight
                    text: root.removalConfirmationText
                    checked: root.removalConfirmed
                    enabled: root.removalConfirmationEnabled
                    font.family: root.fontFamily
                }
                OperatorButton {
                    id: removeButton
                    objectName: "packageRemove"
                    width: Math.min(root.actionWidth, parent.width)
                    height: root.controlHeight
                    text: "移除已停用的插件包"
                    enabled: root.removeEnabled
                    font.family: root.fontFamily
                }
            }
        }
    }
}
