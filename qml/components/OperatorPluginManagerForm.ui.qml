import QtQuick
import QtQuick.Layouts

// 当前进程核心／可选模块管理绘制；与社区插件包安装页分开。
Item {
    id: root
    objectName: "pluginManagerForm"
    implicitWidth: 1200
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias refreshControl: refreshButton
    property alias spacing: root.sectionSpacing
    property int moduleCount: 0
    property Component moduleDelegate: null
    property Component featureConfiguration: null
    property alias configurationControl: configurationButton
    property bool configurationExpanded: false
    property bool configurationActive: true
    readonly property real moduleDelegateWidth: modulesColumn.width
    property bool refreshEnabled: false
    property string headingText: "插件管理 · 当前进程"
    property string descriptionText: "Designer绘制参考 · 未接通原生目录，没有发现或加载模块。"
    property string emptyText: "尚无原生模块清单；本绘制层不生成插件或启用状态。"
    property string statusText: "原生宿主未接通；没有选择、启用或连接插件。"
    property real sectionSpacing: 12
    property real headerMinimumHeight: 94
    property real headerInset: 14
    property real headerTop: 8
    property real headerBottom: 9
    property real headerGap: 4
    property real headerColumnGap: 16
    property real headerBreakpoint: 700
    property real headingMinimumHeight: 30
    property real descriptionMinimumHeight: 43
    property real refreshWidth: 164
    property real refreshHeight: 36
    property real headingSize: 17
    property real noteSize: 12
    property real actionSize: 14
    property real statusMinimumHeight: 48
    property real statusPadding: 8
    property real emptyMinimumHeight: 46
    property real rowMinimumHeight: 144
    property real rowContentMargin: 14
    property real rowTopInset: 10
    property real rowBottomInset: 10
    property real rowColumnGap: 34
    property real rowGap: 12
    property real rowBreakpoint: 900
    property real rowIdentityWidth: 228
    property real rowIdentitySpacing: 4
    property real rowIdentityHintGap: 10
    property real rowRoleMinimumHeight: 28
    property real rowIdentityMinimumHeight: 26
    property real rowClassificationMinimumHeight: 44
    property real rowStatusSpacing: 6
    property real rowNameMinimumHeight: 28
    property real rowStatusMinimumHeight: 70
    property real rowActionWidth: 182
    property real rowControlHeight: 36
    property real rowActionTop: 8
    property real rowActionSpacing: 12
    property real rowActionNoteGap: 8
    property real rowActionNoteMinimumHeight: 24
    property real rowSeparatorInset: 14
    property real rowSeparatorWidth: 1
    property real rowRoleSize: 15
    property real rowIdentitySize: 12
    property real rowClassificationSize: 11
    property real rowNameSize: 13
    property real rowActionNoteSize: 10
    property color surfaceColor: Theme.hudSolid
    property color rowSurfaceColor: Theme.hudSurface
    property color outlineColor: Theme.hudBorder
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily
    property string identityFontFamily: Theme.numberFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        Rectangle {
            width: parent.width
            height: Math.max(root.headerMinimumHeight, headerGrid.implicitHeight + root.headerTop + root.headerBottom)
            color: root.rowSurfaceColor
            OperatorOutline { color: root.outlineColor }
            GridLayout {
                id: headerGrid
                x: root.headerInset
                y: root.headerTop
                width: Math.max(0, parent.width - root.headerInset * 2)
                columns: width >= root.headerBreakpoint ? 2 : 1
                columnSpacing: root.headerColumnGap
                rowSpacing: root.sectionSpacing
                Column {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    spacing: root.headerGap
                    OperatorText { width: parent.width; height: Math.max(root.headingMinimumHeight, implicitHeight); text: root.headingText; size: root.headingSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    OperatorText { width: parent.width; height: Math.max(root.descriptionMinimumHeight, implicitHeight); text: root.descriptionText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                }
                OperatorButton { id: refreshButton; objectName: "pluginManagerRefresh"; Layout.fillWidth: headerGrid.columns === 1; Layout.minimumWidth: 0; Layout.preferredWidth: root.refreshWidth; Layout.preferredHeight: root.refreshHeight; text: "刷新插件目录"; enabled: root.refreshEnabled; font.family: root.fontFamily; font.pixelSize: Math.max(root.actionSize, 9.5 / Math.max(0.1, hudScale)); textColor: root.textColor }
            }
        }
        OperatorButton {
            id:configurationButton
            objectName:"pluginManagerConfigurationToggle"
            width:Math.min(parent.width,320);height:38
            visible:root.featureConfiguration!==null
            text:root.configurationExpanded ? "收起视觉与队内通信参数" : "配置视觉与队内通信"
            primary:root.configurationExpanded
        }
        Loader {
            objectName:"pluginManagerFeatureConfiguration"
            width:parent.width
            visible:root.configurationExpanded
            active:root.configurationActive
            focus:true
            sourceComponent:root.featureConfiguration
        }
        Column {
            id: modulesColumn
            objectName: "pluginManagerModules"
            width: parent.width
            spacing: root.sectionSpacing
            visible: root.moduleCount > 0
            Repeater { model: root.moduleCount; delegate: root.moduleDelegate }
        }
        OperatorText { width: parent.width; height: Math.max(root.emptyMinimumHeight, implicitHeight); visible: root.moduleCount === 0; text: root.emptyText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: Math.max(root.statusMinimumHeight, implicitHeight + root.statusPadding); text: root.statusText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
}
