import QtQuick

OperatorSection {
    id: root
    property var rows: []
    property real labelSize: 11
    property real valueSize: 12
    property real rowHeight: 40
    property real detailMinimumHeight: 74
    property real labelHeight: 30
    property real detailValueTop: 32
    property real detailBottomPadding: 6
    property real labelFraction: 0.42
    property real valueLeftFraction: 0.44
    property real separatorHeight: 1
    property real separatorOpacity: 0.35
    property string numericFontFamily: Theme.numberFamily
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color separatorColor: Theme.line
    readonly property var displayRows: sequence(rows)
    implicitHeight: lines.implicitHeight + root.bodyTop + root.contentMargin
    height: implicitHeight
    function sequence(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length)
            && value.length >= 0 ? Array.from(value) : [];
    }
    function shown(value) { return value === undefined || value === null ? "—" : String(value); }
    Column {
        id: lines
        width: parent.width
        Repeater {
            model: root.displayRows.length
            OperatorDiagnosticRowForm {
                required property int index
                drawingBackgroundVisible: false
                readonly property var entry: root.displayRows[index] ?? ({})
                width: lines.width
                detail: !!entry.detail
                numeric: entry.numeric ?? false
                labelText: root.shown(entry.label)
                valueText: root.shown(entry.value)
                rowHeight: root.rowHeight
                detailMinimumHeight: root.detailMinimumHeight
                labelHeight: root.labelHeight
                detailValueTop: root.detailValueTop
                detailBottomPadding: root.detailBottomPadding
                labelFraction: root.labelFraction
                valueLeftFraction: root.valueLeftFraction
                separatorHeight: root.separatorHeight
                separatorOpacity: root.separatorOpacity
                labelSize: root.labelSize
                valueSize: root.valueSize
                fontFamily: root.fontFamily
                numericFontFamily: root.numericFontFamily
                textColor: root.textColor
                mutedColor: root.mutedColor
                separatorColor: root.separatorColor
            }
        }
    }
}
