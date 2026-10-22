import QtQuick
import "UiFormat.js" as Format
import "OperatorShortcutRegistry.js" as Registry

Item {
    id: root
    required property var ui
    required property var owner
    property var inputState: null
    readonly property bool active: owner?.active === true && owner?.auxiliaryInteractionBlocked !== true
    readonly property bool editing: owner?.activeFocusItem?.readOnly === false
    readonly property bool captured: inputState?.mouseCaptureEnabled === true
    readonly property bool captureDesired: typeof inputState?.captureDesired === "boolean" ? inputState.captureDesired : captured
    readonly property bool hudAvailable: active && !editing && ui?.modalActive === false && !ui?.resultPresentationVisible
    readonly property int role: (ui?.clientID ?? 0) % 100
    readonly property var preferences: ui?.shortcutPreferencesObject
    readonly property var globalActions: Registry.actions.filter(item=>["always","hud","hero","rune"].includes(item.scope))

    function samePanel(item) {
        if (item.id==="exchange") return ui.commonCommandOpen || ui.roleOpen && ["engineer","air"].includes(ui.resolvedRoleSection);
        if(item.panel==="commands")return ui.commonCommandOpen;
        if(item.panel==="hero" || item.panel==="rune")return ui.roleOpen && ui.resolvedRoleSection===item.panel;
        return item.panel && ((item.panel==="settings" && ui.tuningOpen)
            || (item.panel==="injury" && ui.injuryOpen) || (item.panel==="help" && ui.helpOpen));
    }
    function available(item) {
        if(item.id==="capture")return active;
        if (!active || editing || item.roles && !item.roles.includes(role)) return false;
        // Mouse interaction is disabled during capture; eligibility still owns
        // the H route so opening its panel can suspend and later restore capture.
        if(item.id==="exchange" && !samePanel(item) && !ui.dashboardObject.exchangeHitArea.actionAvailable) return false;
        if(item.scope==="always")return true;
        if(item.scope==="hero" || item.scope==="rune")
            return !captured && Format.validLogin(ui.clientID) && (hudAvailable || samePanel(item));
        return hudAvailable || samePanel(item);
    }
    function activate(id) {
        const item=Registry.action(id);
        if(!item || !available(item) || preferences?.recording) return;
        if(id==="fullscreen") {releaseCapture();owner.toggleFullscreen();return;}
        if(id==="capture") {ui.mouseCaptureRequested(!captureDesired);return;}
        if(id==="situation") {releaseCapture();if(typeof owner.openSituation==="function")owner.openSituation();return;}
        if(id==="status" || id==="help" || id==="injury") {
            if(id==="help")ui.helpPanelObject.editorMode=false;
            ui.openPanel(item.panel);
            (id==="status" ? ui.statusPanelObject : id==="help" ? ui.helpPanelObject : ui.damagePanelObject).heldOpen=true;
            if(id==="injury")ui.damagePanelObject.selectedTab=0;
            return;
        }
        if(id==="exchange") {
            if(samePanel(item))ui.openPanel("none");
            else if(role===2 || role===6)ui.openPanel(role===2 ? "engineer" : "air");
            else {ui.openPanel("commands");ui.exchangePanelObject.openRemote();}
            return;
        }
        if(id==="settings" || id==="injury") {ui.openPanel(samePanel(item) ? "none" : item.panel);return;}
        if(id==="heroEnter" || id==="heroExit") {ui.heroPanelObject.beginHold(id==="heroEnter","keyboard");return;}
        if(id==="runeHold") {ui.runePanelObject.beginHold("keyboard");return;}
        if(id==="airEnd") {ui.openPanel("air");Qt.callLater(()=>ui.airPanelObject.request(0));return;}
        if(id==="ammo42" || id==="ammo17") {
            const kind=id==="ammo42" ? "buy42" : "buy17";
            if(ui.commonCommandOpen && ui.exchangePanelObject.selectedTab===1 && ui.exchangePanelObject.supplyKind===kind)ui.openPanel("none");
            else {ui.openPanel("commands");ui.exchangePanelObject.openSupply(kind);}
            return;
        }
        if(id==="layout") {ui.openPanel(ui.layoutOpen ? "none" : "layout");return;}
        if(id==="map") {ui.openPanel(ui.mapMarkOpen ? "none" : "map");return;}
        ui.openPanel(item.panel);
        if(id==="shortcutPanel"){ui.helpPanelObject.editorMode=true;ui.helpPanelObject.heldOpen=false;}
    }
    function releaseCapture() {
        if(typeof inputState?.suspendMouseCapture==="function")inputState.suspendMouseCapture();
        else if(captured && typeof inputState?.requestMouseCapture==="function")inputState.requestMouseCapture(false);
    }
    function releaseKey(key) {
        if(key===Qt.Key_Tab && ui.statusPanelObject.heldOpen)ui.openPanel("none");
        if(key===Qt.Key_F12 && ui.helpPanelObject.heldOpen)ui.openPanel("none");
        if(key===Qt.Key_QuoteLeft && ui.damagePanelObject.heldOpen)ui.openPanel("none");
        for(const id of ["heroEnter","heroExit","runeHold"])
            if(Registry.releases(preferences ? preferences.sequence(id) : Registry.sequence(id,{}),key)) {
                if(id==="runeHold")ui.runePanelObject.endHold("keyboard");else ui.heroPanelObject.endHold("keyboard");
            }
    }
    function cancelHolds() {
        ui.heroPanelObject.cancelHold();ui.runePanelObject.cancelHold();
        if(ui.statusPanelObject.heldOpen || ui.helpPanelObject.heldOpen || ui.damagePanelObject.heldOpen)ui.openPanel("none");
    }
    onActiveChanged: if(!active)cancelHolds()
    Repeater {
        model: root.globalActions
        Item {
            id: route
            required property var modelData
            OperatorActionShortcut {
                scopeItem: root
                actionId: route.modelData.id
                allowEditing: route.modelData.id==="capture"
                available: root.available(route.modelData)
                onActivated: root.activate(route.modelData.id)
            }
        }
    }
}
