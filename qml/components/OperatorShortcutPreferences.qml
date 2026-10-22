import QtQuick
import "OperatorShortcutRegistry.js" as Registry

QtObject {
    id: root
    property bool editable: false
    property var bindings: ({})
    property var draft: ({})
    property string recording: ""
    property string feedback: ""
    readonly property bool dirty: JSON.stringify(draft)!==JSON.stringify(bindings)
    readonly property string serialized: JSON.stringify({version:1,bindings:bindings})
    signal edited
    onEditableChanged: if (!editable) { recording="";draft=Object.assign({},bindings); }
    function sequence(id) { return Registry.sequence(id,bindings); }
    function beginEdit() { recording="";draft=Object.assign({},bindings);feedback=""; }
    function restore(json) {
        if (typeof json!=="string" || json.length>16384) return;
        try { const value=JSON.parse(json);if(value.version===1)bindings=Registry.clean(value.bindings); } catch(error) {}
        beginEdit();
    }
    function assign(id,value) {
        if (!editable) return false;
        const reason=Registry.problem(id,value,draft);
        if(reason) {feedback=reason;return false;}
        const next=Object.assign({},draft);
        if (value===Registry.action(id).key) delete next[id]; else next[id]=value;
        draft=next;recording="";feedback="已修改草稿，保存后生效";return true;
    }
    function resetOne(id) { return assign(id,Registry.action(id)?.key ?? ""); }
    function resetAll() { if(editable) {draft={};recording="";feedback="默认按键已载入草稿，保存后生效";} }
    function save() {
        if (!editable || recording) return;
        for(const item of Registry.actions) if(!item.fixed) {
            const reason=Registry.problem(item.id,Registry.sequence(item.id,draft),draft);
            if(reason) {feedback=item.title+"："+reason;return;}
        }
        bindings=Object.assign({},draft);feedback="快捷键已保存并生效";edited();
    }
}
