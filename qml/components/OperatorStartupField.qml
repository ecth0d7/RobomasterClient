import QtQuick

OperatorStartupFieldForm {
    id: root
    signal valueEdited(string value)
    Connections {
        target: root.inputControl
        function onTextEdited() { root.valueEdited(root.inputControl.text); }
    }
}
