import QtQuick
import QtQuick.Controls
import "OperatorOwnStatusData.js" as Own

OperatorOwnStateHintsForm {
    id: root
    property var records: []
    // QVariant 顺序容器先转为 JS 数组；不改写投影条目或它的可信／时效属性。
    readonly property var normalizedRecords: normalizeRecords(records)
    readonly property var ordered: ["power_cutoff","respawn_weakness","power_bonus"]
        .map(kind => normalizedRecords.find(record => record.kind === kind))
        .filter(record => record !== undefined)
    readonly property bool mockSource: normalizedRecords.some(record => record.source_kind === "mock")
    hintCount: ordered.length
    sourceCaption: mockSource ? "mock" : "选手端"
    sourceColor: mockSource ? Theme.warning : Theme.muted
    sourceControl.visible: mockSource

    function normalizeRecords(values) {
        if (!values || typeof values !== "object" || !Number.isInteger(values.length) || values.length < 0)
            return [];
        return Array.from(values).filter(record => record !== null && typeof record === "object");
    }
    hintDelegate: Component {
        OperatorOwnStateHintRowForm {
            required property int index
            readonly property var record: root.ordered[index] ?? null
            x: index * (root.width + root.slotGap) / Math.max(1, root.slotCount)
            width: (root.width - root.slotGap * (Math.max(1, root.slotCount) - 1)) / Math.max(1, root.slotCount)
            height: root.height
            labelText: record ? Own.hint(record) : ""
            labelSize: root.labelSize
            fontFamily: root.fontFamily
            labelColor: !record ? Theme.muted : record.kind === "power_bonus"
                ? record.timer_valid && record.estimated_remaining_seconds === 0 ? Theme.muted : Theme.green
                : Theme.red
            Accessible.name: record ? Own.description(record) : ""
            HoverHandler { id: hover }
            ToolTip.visible: hover.hovered
            ToolTip.delay: 450
            ToolTip.text: record ? Own.description(record) : ""
        }
    }
}
