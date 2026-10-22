import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorFocus.js" as PanelFocus
import "OperatorShortcutRegistry.js" as Shortcuts

OperatorPanelFrameForm {
    id: root
    readonly property var shortcutPreferences: Window.window?.ui?.shortcutPreferencesObject ?? null
    // 社区正文可以复用 PanelFrame；Tab/Esc 只由最外层窗口接管，避免相同
    // WindowShortcut 歧义和嵌套焦点陷阱，仍能走到宿主关闭／返回按钮。
    readonly property bool operatorPanelKeyboardBoundary: true
    readonly property bool panelKeyboardRoot: {
        for (let ancestor = parent; ancestor; ancestor = ancestor.parent)
            if (ancestor.operatorPanelKeyboardBoundary === true) return false;
        return true;
    }
    function shortcutLabel(id) { return shortcutPreferences ? shortcutPreferences.sequence(id) : Shortcuts.sequence(id,{}); }
    function shortcutKey(id,key) { return Shortcuts.keyCode(shortcutLabel(id))===key; }
    function shortcutPressed(id,event) { return Shortcuts.matches(shortcutLabel(id),event); }
    function shortcutReleased(id,key) { return Shortcuts.releases(shortcutLabel(id),key); }
    signal closeRequested
    property real revealProgress: 1
    opacity: revealProgress
    NumberAnimation { id: reveal; target: root; property: "revealProgress"; to: 1; duration: Theme.transitionMs; easing.type: Easing.OutCubic }
    onVisibleChanged: {
        reveal.stop();
        revealProgress = visible && !Theme.reducedMotion ? 0 : 1;
        if (visible) { forceActiveFocus(); reveal.start(); }
    }
    Connections { target: Theme; function onReducedMotionChanged() { if (Theme.reducedMotion) {reveal.stop();root.revealProgress=1;} } }
    Keys.onEscapePressed: event => {
        event.accepted = root.panelKeyboardRoot;
        if (event.accepted) root.closeRequested();
    }
    Shortcut { sequence: "Tab"; enabled: root.panelKeyboardRoot && root.visible && root.Window.window?.active === true; autoRepeat: false; onActivated: PanelFocus.move(root, root.Window.window.activeFocusItem, true) }
    Shortcut { sequence: "Shift+Tab"; enabled: root.panelKeyboardRoot && root.visible && root.Window.window?.active === true; autoRepeat: false; onActivated: PanelFocus.move(root, root.Window.window.activeFocusItem, false) }

    Connections {
        target: root.closeControl
        function onClicked() { root.closeRequested(); }
    }
}
