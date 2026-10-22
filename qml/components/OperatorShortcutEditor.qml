import QtQuick
import QtQuick.Window
import "OperatorShortcutRegistry.js" as Registry
import "OperatorShortcutData.js" as KeysGuide

OperatorPanelFrame {
    id: root
    property int clientID: 0
    property bool previewOnly: false
    property bool routesInstalled: false
    property var preferences: null
    property var inputState: null
    property int page: 0
    property bool heldOpen: false
    property bool contentVisited: false
    Component.onCompleted: if (visible) contentVisited = true
    property string query: ""
    readonly property var globalScopes: ["always","hud","hero","rune"]
    readonly property var entries: {
        const bindings=preferences?.draft ?? {};
        const term=query.trim().toLowerCase();
        return Registry.actions.filter(item=>{
            if(item.roles && !item.roles.includes(clientID%100))return false;
            const global=globalScopes.includes(item.scope);
            if(page===0 && (!global || item.roles) || page===1 && (!global || !item.roles) || page===2 && global || page===3)return false;
            return !term || (item.title+" "+item.text+" "+Registry.sequence(item.id,bindings)+" "+Registry.scopeLabel(item.scope)).toLowerCase().includes(term);
        });
    }
    readonly property var tabTitles: ["通用界面", "本机角色", "面板操作", "输入与边界"]
    readonly property var guideEntries: sequence(KeysGuide.entries(2, clientID, previewOnly, routesInstalled))
    signal openPanelRequested(string panel)
    title: "快捷键管理 · " + (clientID || "未选身份")
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1100
    height: 650
    function sequence(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length) ? Array.from(value) : [];
    }
    function shown(value) { return value === undefined || value === null ? "未提供" : String(value); }
    function beginRecording(id) {
        if(!preferences?.editable)return;
        heldOpen=false;preferences.recording=id;
        preferences.feedback="按下新组合键；Esc取消，Backspace停用这个快捷键";
        forceActiveFocus();
    }
    function openEntry(item) {
        heldOpen=false;
        openPanelRequested(item.id==="exchange" ? clientID%100===2 ? "engineer" : clientID%100===6 ? "air" : "commands" : item.panel);
    }
    onVisibleChanged: {
        if(visible) { contentVisited=true;preferences?.beginEdit();forceActiveFocus(); }
        else {heldOpen=false;if(preferences)preferences.recording="";}
    }
    Keys.onEscapePressed: event=>{
        event.accepted=true;
        if(preferences?.recording) {preferences.recording="";preferences.feedback="已取消按键录入";}
        else closeRequested();
    }
    Keys.onPressed: event=>{
        if(!preferences?.recording || event.isAutoRepeat)return;
        event.accepted=true;
        if(event.key===Qt.Key_Backspace) {preferences.assign(preferences.recording,"");return;}
        const sequence=Registry.eventSequence(event);
        if(sequence)preferences.assign(preferences.recording,sequence);
    }
    Keys.onReleased: event=>{
        if(event.key===Qt.Key_F12 && heldOpen && !event.isAutoRepeat) {event.accepted=true;closeRequested();}
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if(root.Window.window?.active!==true) {
                if(root.preferences)root.preferences.recording="";
                if(root.heldOpen)root.closeRequested();
            }
        }
    }
    OperatorHelpForm {
        id: helpForm
        anchors.fill: parent
        tabCount: root.tabTitles.length
        entryCount: root.contentVisited ? root.entries.length : 0
        guideCount: root.contentVisited ? root.guideEntries.length : 0
        showGuide: root.page === 3
        queryText: root.query
        statusText: root.preferences?.editable ? "快捷键配置 · 保存后立即生效" : "配置宿主不可用 · 快捷键只读"
        statusWarning: root.preferences?.editable !== true
        feedbackText: root.preferences?.feedback || (root.heldOpen ? "松开F12返回；点击页签或搜索框固定打开。" : "修改后保存；Esc关闭。文本输入优先，机器人命令保持选择与确认。")
        recording: !!root.preferences?.recording
        emptyText: "没有匹配项"
        resetAllEnabled: root.preferences?.editable === true
        undoEnabled: root.preferences?.dirty === true
        saveEnabled: root.preferences?.editable === true && root.preferences.dirty && !root.preferences.recording
        tabDelegate: Component {
            OperatorButton {
                required property int index
                objectName: "shortcutTab_" + index
                width: helpForm.tabDelegateWidth
                height: helpForm.controlHeight
                text: root.tabTitles[index] ?? "未提供页签"
                primary: root.page === index
                textColor: helpForm.textColor
                font.family: helpForm.fontFamily
                font.pixelSize: Math.max(helpForm.inputSize, 9.5 / Math.max(0.1, hudScale))
                onClicked: { root.page = index; root.heldOpen = false; }
            }
        }
        actionDelegate: Component {
            OperatorHelpActionRowForm {
                id: row
                required property int index
                readonly property var entry: root.entries[index] ?? ({})
                readonly property string binding: Registry.sequence(entry.id, root.preferences?.draft ?? {})
                objectName: "shortcutAction_" + (entry.id ?? index)
                width: helpForm.actionDelegateWidth
                recording: root.preferences?.recording === entry.id
                bindingText: recording ? "请按下组合键…" : binding || "未分配"
                scopeText: root.shown(Registry.scopeLabel(entry.scope))
                titleText: root.shown(entry.title)
                descriptionText: root.shown(entry.text)
                changeText: entry.fixed ? "固定" : "改键"
                changeEnabled: !entry.fixed && root.preferences?.editable === true
                resetEnabled: !entry.fixed && root.preferences?.editable === true
                changeAccessibleName: "修改" + root.shown(entry.title) + "快捷键"
                openVisible: !!entry.panel && !entry.hold && entry.panel !== "help"
                openEnabled: openVisible
                surfaceColor: helpForm.rowSurfaceColor
                textColor: helpForm.textColor
                mutedColor: helpForm.mutedColor
                borderColor: helpForm.rowBorderColor
                separatorColor: helpForm.separatorColor
                recordingColor: helpForm.recordingColor
                bindingColor: recording ? helpForm.recordingColor : binding ? helpForm.textColor : helpForm.mutedColor
                fontFamily: helpForm.fontFamily
                numberFamily: helpForm.numberFamily
                inputSize: helpForm.inputSize
                noteSize: helpForm.actionNoteSize
                titleSize: helpForm.actionTitleSize
                bindingSize: helpForm.actionBindingSize
                Connections { target: row.changeControl; function onClicked() { if (row.changeEnabled) root.beginRecording(row.entry.id); } }
                Connections {
                    target: row.resetControl
                    function onClicked() {
                        if (!row.resetEnabled) return;
                        root.heldOpen = false; root.preferences.resetOne(row.entry.id);
                    }
                }
                Connections { target: row.openControl; function onClicked() { if (row.openVisible && row.openEnabled) root.openEntry(row.entry); } }
            }
        }
        guideDelegate: Component {
            OperatorHelpGuideRowForm {
                required property int index
                readonly property var entry: root.guideEntries[index] ?? ({})
                objectName: "shortcutGuide_" + index
                width: helpForm.guideDelegateWidth
                keyText: root.shown(entry.key)
                titleText: root.shown(entry.title)
                descriptionText: root.shown(entry.text)
                textColor: helpForm.textColor
                mutedColor: helpForm.mutedColor
                fontFamily: helpForm.fontFamily
                numberFamily: helpForm.numberFamily
                noteSize: helpForm.noteSize
                titleSize: helpForm.guideTitleSize
                keySize: helpForm.guideKeySize
            }
        }
    }
    Connections {
        target: helpForm.searchControl
        function onTextChanged() { if (helpForm.searchControl.text !== root.query) root.query = helpForm.searchControl.text; }
        function onActiveFocusChanged() { if (helpForm.searchControl.activeFocus) root.heldOpen = false; }
    }
    Connections {
        target: helpForm.resetAllControl
        function onClicked() {
            if (root.preferences?.editable !== true) return;
            root.heldOpen = false; root.preferences.resetAll();
        }
    }
    Connections { target: helpForm.undoControl; function onClicked() { if (root.preferences?.dirty === true) root.preferences.beginEdit(); } }
    Connections { target: helpForm.saveControl; function onClicked() { if (helpForm.saveEnabled) root.preferences.save(); } }
}
