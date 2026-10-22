import QtQuick
import QtQuick.Layouts

// One configured peer's drawing. Native identity checks and all mutations
// remain in the ordinary team wrapper; a blank Form invents no peer/data.
Item {
    id: root
    objectName: "teamSetupPeerForm"
    implicitWidth: 1300
    implicitHeight: peerSection.height
    width: implicitWidth
    height: implicitHeight
    property alias nodeControl: nodeField.inputControl
    property alias certificateControl: certificateField.inputControl
    property alias fingerprintControl: fingerprintField.inputControl
    property alias robotControl: robotField.selectControl
    property alias canSendControl: canSendCheck
    property alias canAggregateControl: canAggregateCheck
    property alias removeControl: removeButton
    property alias sectionControl: peerSection
    property Component grantsDelegate: null
    readonly property real grantDelegateWidth: peerColumn.width
    property string titleText: "队友 · 待填写身份"
    property string nodeValue: ""
    property string certificateValue: ""
    property string fingerprintValue: ""
    property var robotTitles: []
    property int robotIndex: -1
    property string robotDisplayText: "选择同阵营且未重复的机器人"
    property string robotHint: "先选择本机阵营与角色。"
    property bool canSendValue: false
    property bool canAggregateValue: false
    property bool inputEditable: false
    property bool removeEnabled: false
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real columnGap: 12
    property real actionSpacing: 12
    property real fieldBreakpoint: 760
    property real checkWidth: 300
    property real removeWidth: 156
    property real controlHeight: 38
    property real labelHeight: 26
    property real labelGap: 4
    property real hintGap: 8
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real sectionTitleSize: 14
    property real contentMargin: 14
    property real bodyTop: 47
    property real labelSize: 12
    property real noteSize: 12
    property real inputSize: 14
    property real hintSize: 11
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorSection {
        id: peerSection
        width: root.width
        height: peerColumn.implicitHeight + bodyTop + contentMargin
        title: root.titleText
        titleSize: root.sectionTitleSize
        contentMargin: root.contentMargin
        bodyTop: root.bodyTop
        fontFamily: root.fontFamily
        titleColor: root.textColor
        outlineColor: root.separatorColor
        surfaceColor: root.surfaceColor
        Column {
            id: peerColumn
            width: parent.width
            spacing: root.formSpacing
            GridLayout {
                width: parent.width
                columns: width >= root.fieldBreakpoint ? 2 : 1
                columnSpacing: root.columnGap
                rowSpacing: root.fieldSpacing
                OperatorStartupFieldForm {
                    id: nodeField
                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                    label: "队友节点标识"; value: root.nodeValue; maximumLength: 64; editable: root.inputEditable
                    hint: "必须与队友配置完全一致。"
                    labelHeight: root.labelHeight; labelGap: root.labelGap; controlHeight: root.controlHeight
                    hintGap: root.hintGap; minimumHintHeight: root.minimumHintHeight; hintBottomPadding: root.hintBottomPadding
                    labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                    textColor: root.textColor; secondaryTextColor: root.secondaryTextColor; warningColor: root.warningColor
                    inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.separatorColor
                    fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                }
                OperatorSetupSelectForm {
                    id: robotField
                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                    label: "队友语义机器人"
                    choices: root.robotTitles
                    selectedIndex: root.robotIndex
                    selectionText: root.robotDisplayText
                    hint: root.robotHint
                    editable: root.inputEditable
                    labelHeight: root.labelHeight; labelGap: root.labelGap; controlHeight: root.controlHeight
                    hintGap: root.hintGap; minimumHintHeight: root.minimumHintHeight; hintBottomPadding: root.hintBottomPadding
                    labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                    textColor: root.textColor; secondaryTextColor: root.secondaryTextColor; warningColor: root.warningColor
                    inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.separatorColor
                    fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                }
                OperatorStartupFieldForm {
                    id: certificateField
                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                    label: "队友签名证书文件"; value: root.certificateValue; maximumLength: 4096; editable: root.inputEditable
                    hint: "相对引用以共享配置文件目录为基准。"
                    labelHeight: root.labelHeight; labelGap: root.labelGap; controlHeight: root.controlHeight
                    hintGap: root.hintGap; minimumHintHeight: root.minimumHintHeight; hintBottomPadding: root.hintBottomPadding
                    labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                    textColor: root.textColor; secondaryTextColor: root.secondaryTextColor; warningColor: root.warningColor
                    inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.separatorColor
                    fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                }
                OperatorStartupFieldForm {
                    id: fingerprintField
                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                    label: "SHA256公钥固定指纹 / SPKI"; value: root.fingerprintValue; maximumLength: 64; editable: root.inputEditable
                    hint: "由真实队友证书提供，64位小写十六进制；不自动生成。"
                    labelHeight: root.labelHeight; labelGap: root.labelGap; controlHeight: root.controlHeight
                    hintGap: root.hintGap; minimumHintHeight: root.minimumHintHeight; hintBottomPadding: root.hintBottomPadding
                    labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                    textColor: root.textColor; secondaryTextColor: root.secondaryTextColor; warningColor: root.warningColor
                    inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.separatorColor
                    fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                }
            }
            Flow {
                width: parent.width
                spacing: root.actionSpacing
                OperatorCheckBox {
                    id: canSendCheck
                    width: Math.min(root.checkWidth, parent.width)
                    height: root.controlHeight
                    text: "允许此队友发送授权字段"
                    checked: root.canSendValue
                    enabled: root.inputEditable
                    textColor: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                }
                OperatorCheckBox {
                    id: canAggregateCheck
                    width: Math.min(root.checkWidth, parent.width)
                    height: root.controlHeight
                    text: "允许此队友承担汇总发布"
                    checked: root.canAggregateValue
                    enabled: root.inputEditable
                    textColor: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                }
                OperatorButton {
                    id: removeButton
                    width: Math.min(root.removeWidth, parent.width)
                    height: root.controlHeight
                    text: "移除此队友"
                    enabled: root.removeEnabled
                    textColor: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                }
            }
            // One persistent editor per peer; sourceComponent/Loader churn
            // must not replace its nested editing fields on draft updates.
            Repeater { model: 1; delegate: root.grantsDelegate }
        }
    }
}
