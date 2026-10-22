import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorFocus.js" as PanelFocus
import "OperatorShortcutRegistry.js" as Shortcuts

FocusScope {
    id: root
    default property alias panelContent: body.data
    property string title: ""
    property string stateText: ""
    property color accent: Theme.text
    property bool customIcon: false
    property url iconSource: ""
    property url backgroundSource: ""
    property real contentMargin: 16
    property real headerCenterY: 27
    property real titleHeight: 32
    property real titleSize: 16
    property real iconSize: 32
    property real iconTitleGap: 12
    property real closeSize: 32
    property real titleCloseGap: 28
    property real stateTop: 48
    property real stateHeight: 22
    property real stateSize: 11
    property real dividerTop: 79
    property real bodyTop: 94
    property bool closeButton: true
    property bool manageFocusTraversal:true
    property bool stateVisible: true
    property bool dividerVisible: true
    property bool headingBand: false
    property int titleAlignment: Text.AlignLeft
    property real frameRadius: 3
    property color surfaceColor: Theme.hudSurface
    property color outlineColor: Theme.hudBorder
    property color stateColor: Theme.muted
    property color dividerColor: Theme.line
    readonly property var shortcutPreferences: Window.window?.ui?.shortcutPreferencesObject ?? null
    function shortcutLabel(id) { return shortcutPreferences ? shortcutPreferences.sequence(id) : Shortcuts.sequence(id,{}); }
    function shortcutKey(id,key) { return Shortcuts.keyCode(shortcutLabel(id))===key; }
    function shortcutPressed(id,event) { return Shortcuts.matches(shortcutLabel(id),event); }
    function shortcutReleased(id,key) { return Shortcuts.releases(shortcutLabel(id),key); }
    signal closeRequested
    implicitWidth: 350
    implicitHeight: 330
    width: implicitWidth
    height: implicitHeight
    onVisibleChanged: if (visible) forceActiveFocus()
    Keys.onEscapePressed: event => { event.accepted = true; root.closeRequested(); }
    Shortcut { sequence: "Tab"; enabled: root.manageFocusTraversal && root.visible && root.Window.window?.active === true; autoRepeat: false; onActivated: PanelFocus.move(root, root.Window.window.activeFocusItem, true) }
    Shortcut { sequence: "Shift+Tab"; enabled: root.manageFocusTraversal && root.visible && root.Window.window?.active === true; autoRepeat: false; onActivated: PanelFocus.move(root, root.Window.window.activeFocusItem, false) }

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundSource.toString().length === 0
        color: root.surfaceColor
        OperatorOutline { color: root.outlineColor }
        radius: root.frameRadius
    }
    Image {
        anchors.fill: parent
        source: root.backgroundSource
        visible: source.toString().length > 0
        fillMode: Image.Stretch
        mipmap: true
    }
    Rectangle {
        width: root.width; height: root.bodyTop - 10
        visible: root.headingBand
        gradient: Gradient {
            GradientStop { position: 0; color: "#b9464646" }
            GradientStop { position: 1; color: "#fa181818" }
        }
    }
    OperatorPanelGlyph {
        x: root.contentMargin
        y: root.headerCenterY - height / 2
        width: root.iconSize
        height: root.iconSize
        imageSource: root.iconSource
        visible: imageSource.toString().length > 0
    }
    OperatorText {
        x: root.contentMargin + (root.iconSource.toString().length || root.customIcon ? root.iconSize + root.iconTitleGap : 0)
        y: root.headerCenterY - height / 2
        width: root.width - x - (root.closeButton ? root.closeSize + root.titleCloseGap : root.contentMargin)
        height: root.titleHeight
        text: root.title
        size: root.titleSize
        color: root.accent
        horizontalAlignment: root.titleAlignment
    }
    OperatorCloseButton {
        x: parent.width - root.contentMargin - width
        y: root.headerCenterY - height / 2
        width: root.closeSize
        height: root.closeSize
        objectName: "roleCloseControl"
        visible: root.closeButton
        closeLabel: "关闭" + root.title
        onClicked: root.closeRequested()
    }
    OperatorText {
        x: root.contentMargin
        y: root.stateTop
        width: root.width - 2 * root.contentMargin
        height: root.stateHeight
        text: root.stateText
        visible: root.stateVisible
        size: root.stateSize
        color: root.stateColor
    }
    Rectangle { x: root.contentMargin; y: root.dividerTop; width: root.width - 2 * root.contentMargin; height: 1; color: root.dividerColor; visible: root.dividerVisible }
    Item {
        id: body
        x: root.contentMargin
        y: root.bodyTop
        width: root.width - 2 * root.contentMargin
        height: root.height - y - root.contentMargin
    }
}
