.pragma library

// 只在当前可见面板内遍历实际控件；不改变机器人输入或命令策略。
function targets(scope) {
    const result = [];
    function walk(item) {
        for (const child of item.children ?? []) {
            if (!child.visible || !child.enabled) continue;
            // ScrollView／Flickable是导航容器，其正文仍有可聚焦输入框。
            const scrolling = typeof child.contentY === "number"
                || child.contentItem && typeof child.contentItem.contentY === "number";
            if (scrolling) { walk(child); continue; }
            if (child.activeFocusOnTab === true || (Number(child.focusPolicy) & 1) !== 0) {
                result.push(child);
                // 控件内部的TextInput／内容项不是第二个Tab停靠点。
                continue;
            }
            walk(child);
        }
    }
    walk(scope);
    return result;
}

function contains(scope, item) {
    for (let current = item; current; current = current.parent)
        if (current === scope) return true;
    return false;
}

function reveal(scope, target) {
    for (let item = target.parent; item && item !== scope; item = item.parent) {
        if (typeof item.contentY !== "number" || typeof item.contentHeight !== "number") continue;
        const point = target.mapToItem(item, 0, 0), bottom = point.y + target.height;
        let position = item.contentY;
        if (point.y < 8) position += point.y - 8;
        else if (bottom > item.height - 8) position += bottom - item.height + 8;
        // ListView的内联header位于originY之前；把下界写成0会让Tab无法重新显露顶部控件。
        const minimum = (Number(item.originY) || 0) - (Number(item.headerItem?.height) || 0);
        const maximum = minimum + Math.max(0, item.contentHeight - item.height);
        item.contentY = Math.max(minimum, Math.min(maximum, position));
    }
}

function move(scope, current, forward) {
    const controls = targets(scope);
    if (!controls.length) { scope.forceActiveFocus(); return; }
    const index = controls.findIndex(control => contains(control, current));
    const next = index < 0 ? forward ? 0 : controls.length - 1
                          : (index + (forward ? 1 : controls.length - 1)) % controls.length;
    // Tab离开选择框时收起其popup，避免留下覆盖下一控件的旧菜单。
    for (const control of controls)
        if (control.popup?.opened === true) control.popup.close();
    controls[next].forceActiveFocus(forward ? 1 : 2); // Qt.TabFocusReason / BacktabFocusReason
    reveal(scope, controls[next]);
}
