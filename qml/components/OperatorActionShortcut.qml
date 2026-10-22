import QtQuick
import QtQuick.Window
import "OperatorShortcutRegistry.js" as Registry

Shortcut {
    id: root
    required property string actionId
    property bool available: true
    property bool allowEditing: false
    property Item scopeItem: null
    readonly property var hostWindow: scopeItem ? scopeItem.Window.window : null
    readonly property var preferences: hostWindow?.ui?.shortcutPreferencesObject ?? null
    readonly property string binding: preferences ? preferences.sequence(actionId) : Registry.sequence(actionId,{})
    readonly property var focusItem: hostWindow?.activeFocusItem
    // Text fields and open selects own their keys. Commands do not escape them.
    readonly property bool editing: focusItem?.readOnly === false || focusItem?.popup?.opened === true
    sequences: binding==="Return" ? ["Return","Enter"] : binding.length ? [binding] : []
    autoRepeat: false
    context: Qt.WindowShortcut
    enabled: available && hostWindow?.active === true && !preferences?.recording && (allowEditing || !editing)
}
