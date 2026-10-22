import QtQuick

// 插件窗口的公共绘制层；插件只占正文槽，标题和退出入口由宿主保留。
OperatorPanelFrame {
    id: root
    property alias contentContainer: panelSlot
    property alias libraryControl: libraryButton
    property string packageCaption: "未选择插件"
    property string emptyMessage: "从面板库选择已启用插件提供的面板。"
    property bool contentReady: false
    property real provenanceHeight: 38
    property real contentGap: 12
    property real footerHeight: 42
    property real libraryButtonWidth: 164
    property real statusTextSize: 12
    property color statusTextColor: Theme.muted
    title: "扩展面板"
    iconAsset: "ServerUI_Setting"
    implicitWidth: 1100
    implicitHeight: 720

    OperatorText {
        id: provenanceText
        width: parent.width
        height: root.provenanceHeight
        text: root.packageCaption
        size: root.statusTextSize
        color: root.statusTextColor
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
    Item {
        id: panelSlot
        objectName: "extensionPanelContent"
        y: root.provenanceHeight + root.contentGap
        width: parent.width
        height: Math.max(0, parent.height - y - root.footerHeight - root.contentGap)
        clip: true
    }
    OperatorText {
        x: panelSlot.x + 24
        y: panelSlot.y
        width: Math.max(0, panelSlot.width - 48)
        height: panelSlot.height
        visible: !root.contentReady
        text: root.emptyMessage
        size: 15
        color: root.statusTextColor
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        horizontalAlignment: Text.AlignHCenter
    }
    OperatorText {
        y: parent.height - root.footerHeight
        width: Math.max(0, parent.width - root.libraryButtonWidth - root.contentGap)
        height: root.footerHeight
        text: "Esc 关闭 · 关闭后可从面板库重新打开"
        size: root.statusTextSize
        color: root.statusTextColor
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
    OperatorButton {
        id: libraryButton
        objectName: "extensionPanelLibraryButton"
        x: parent.width - width
        y: parent.height - root.footerHeight
        width: root.libraryButtonWidth
        height: root.footerHeight
        text: "返回面板库"
        Accessible.name: "关闭当前插件面板并返回面板库"
    }
}
