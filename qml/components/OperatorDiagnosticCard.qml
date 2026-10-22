import QtQuick

OperatorSection {
    id: root
    property string status: "—"
    property string state: "unknown"
    property var rows: []
    property color stateColor: state === "ok" ? Theme.green : state === "warning" ? Theme.warning
                                                    : state === "busy" ? Theme.blue : Theme.muted
    property real minimumCardHeight: 184
    property alias statusHeight: drawing.statusHeight
    property alias statusSize: drawing.statusSize
    property alias rowsTop: drawing.rowsTop
    property alias rowSpacing: drawing.rowSpacing
    property alias rowHeight: drawing.rowHeight
    property alias labelSize: drawing.labelSize
    property alias valueSize: drawing.valueSize
    property alias labelFraction: drawing.labelFraction
    property alias valueLeftFraction: drawing.valueLeftFraction
    property alias numericFontFamily: drawing.numericFontFamily
    property alias textColor: drawing.textColor
    property alias mutedColor: drawing.mutedColor
    property alias stateRightInset: drawing.stateRightInset
    property alias stateTop: drawing.stateTop
    property alias stateSize: drawing.stateSize
    property alias stateRadius: drawing.stateRadius
    readonly property var displayRows: sequence(rows)
    implicitHeight: Math.max(minimumCardHeight, drawing.implicitHeight + bodyTop + contentMargin)
    height: implicitHeight
    function sequence(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length)
            && value.length >= 0 ? Array.from(value) : [];
    }
    function shown(value) { return value === undefined || value === null ? "—" : String(value); }
    OperatorDiagnosticCardForm {
        id: drawing
        width: parent.width
        statusText: root.status
        stateColor: root.stateColor
        fontFamily: root.fontFamily
        rowCount: root.displayRows.length
        rowDelegate: Component {
            OperatorDiagnosticRowForm {
                required property int index
                drawingBackgroundVisible: false
                readonly property var entry: root.displayRows[index] ?? ({})
                width: drawing.width
                labelText: root.shown(entry.label)
                valueText: root.shown(entry.value)
                numeric: entry.numeric ?? false
                showSeparator: false
                rowHeight: drawing.rowHeight
                labelHeight: drawing.rowHeight
                labelSize: drawing.labelSize
                valueSize: drawing.valueSize
                labelFraction: drawing.labelFraction
                valueLeftFraction: drawing.valueLeftFraction
                fontFamily: drawing.fontFamily
                numericFontFamily: drawing.numericFontFamily
                textColor: drawing.textColor
                mutedColor: drawing.mutedColor
            }
        }
    }
}
