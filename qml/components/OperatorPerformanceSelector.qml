import QtQuick
import "OperatorPerformance.js" as Performance

// Existing historical-2026 choices and host eligibility are retained. This
// wrapper formats readings and emits an explicit choice; it never changes telemetry.
OperatorSection {
    id: root
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool submissionAvailable: false
    property var controls: ({})
    readonly property bool shooterAllowed: previewOnly ? [1,3,4,5].includes(role) : controls.shooter === true
    readonly property bool chassisAllowed: previewOnly ? [1,3,4,5].includes(role) : controls.chassis === true
    readonly property bool sentryAllowed: role === 7 && (previewOnly || controls.sentry_control === true)
    property string feedback: ""
    property int shooterChoice: 0
    property int chassisChoice: 0
    property int sentryChoice: -1
    property bool shooterSelectionMade: false
    property bool chassisSelectionMade: false
    property bool sentrySelectionMade: false
    property bool selectionChanged: true
    readonly property int role: clientID % 100
    readonly property bool groundRobot: [1, 3, 4, 5, 7].includes(role)
    readonly property bool hasSelection: shooterAllowed && shooterChoice > 0 || chassisAllowed && chassisChoice > 0 || sentryAllowed && sentryChoice >= 0
    readonly property var shooterOptions: Performance.choices("shooter", role)
    readonly property var chassisOptions: Performance.choices("chassis", role)
    readonly property var readingFields: role === 7 ? ["shooter", "chassis", "sentry_control"] : ["shooter", "chassis"]
    readonly property var readingRows: readingFields.map(field => {
        const reading = Performance.reading(root.telemetry, field);
        const label = ({shooter: "发射  ", chassis: "底盘  ", sentry_control: "控制  "})[field];
        return {text: label + reading.text + (reading.state === "stale" ? " · 旧" : ""), stale: reading.state === "stale"};
    })
    readonly property string selectionStatus: !groundRobot ? "当前身份无地面性能设置" : !submissionAvailable ? controls.reason || "当前性能设置不可用" : hasSelection && selectionChanged ? "选择待提交 · 当前值不变" : feedback || (previewOnly ? "离线预览 · 未发送指令" : "生效以选手端同步为准")
    signal selectionIntent(var fields)
    property alias formControl: form
    title: form.sectionTitle
    height: form.sectionHeight
    bodyTop: form.sectionBodyTop
    contentMargin: form.sectionContentMargin
    titleTop: form.sectionTitleTop
    titleHeight: form.sectionTitleHeight
    titleSize: form.sectionTitleSize
    fontFamily: form.fontFamily
    titleColor: form.textColor
    outlineColor: form.separatorColor
    surfaceColor: form.surfaceColor
    onClientIDChanged: clearSelection()
    function clearSelection() {
        selectionChanged = true; shooterChoice = 0; chassisChoice = 0; sentryChoice = -1;
        shooterSelectionMade = false; chassisSelectionMade = false; sentrySelectionMade = false;
    }
    function selectedFields() {
        const fields = {};
        if (shooterAllowed && shooterChoice > 0) fields.shooter = shooterChoice;
        if (chassisAllowed && chassisChoice > 0) fields.chassis = chassisChoice;
        if (sentryAllowed && sentryChoice >= 0) fields.sentry_control = sentryChoice;
        return fields;
    }
    function submit() {
        if (!submissionAvailable || !groundRobot || !hasSelection) return;
        selectionChanged = false; selectionIntent(selectedFields());
    }
    OperatorPerformanceSelectorForm {
        id: form
        anchors.fill: parent
        drawingBackgroundVisible: false
        readingCount: root.readingRows.length
        readingTexts: root.readingRows.map(row => row.text)
        readingStale: root.readingRows.map(row => row.stale)
        shooterTitles: root.shooterOptions.map(item => item.title)
        chassisTitles: root.chassisOptions.map(item => item.title)
        sentryTitles: ["保持当前"].concat(Performance.controlNames)
        shooterIndex: root.shooterSelectionMade || root.shooterChoice > 0 ? root.shooterOptions.findIndex(item => item.value === root.shooterChoice) : -1
        chassisIndex: root.chassisSelectionMade || root.chassisChoice > 0 ? root.chassisOptions.findIndex(item => item.value === root.chassisChoice) : -1
        sentryIndex: root.sentrySelectionMade || root.sentryChoice >= 0 ? root.sentryChoice + 1 : -1
        shooterDisplayText: shooterIndex >= 0 ? shooterTitles[shooterIndex] : "尚未选择 · 保持当前"
        chassisDisplayText: chassisIndex >= 0 ? chassisTitles[chassisIndex] : "尚未选择 · 保持当前"
        sentryDisplayText: sentryIndex >= 0 ? sentryTitles[sentryIndex] : "尚未选择 · 保持当前"
        shooterEditable: root.shooterAllowed && root.submissionAvailable
        chassisEditable: root.chassisAllowed && root.submissionAvailable
        sentryEditable: root.sentryAllowed && root.submissionAvailable
        sentryVisible: root.role === 7
        submitEnabled: root.submissionAvailable && root.groundRobot && root.hasSelection
        statusText: root.selectionStatus
        statusWarning: !root.submissionAvailable
        submitText: root.previewOnly ? "记录性能选择 · 预览" : "提交性能选择"
    }
    Connections {
        target: form.shooterControl
        function onActivated(index) {
            if (index < 0 || index >= root.shooterOptions.length) return;
            root.shooterChoice = root.shooterOptions[index].value;
            root.shooterSelectionMade = true;
            if (root.role === 1) { root.chassisChoice = root.shooterChoice; root.chassisSelectionMade = true; }
            root.selectionChanged = true;
        }
    }
    Connections {
        target: form.chassisControl
        function onActivated(index) {
            if (index < 0 || index >= root.chassisOptions.length) return;
            root.chassisChoice = root.chassisOptions[index].value;
            root.chassisSelectionMade = true;
            if (root.role === 1) { root.shooterChoice = root.chassisChoice; root.shooterSelectionMade = true; }
            root.selectionChanged = true;
        }
    }
    Connections {
        target: form.sentryControl
        function onActivated(index) {
            if (index < 0 || index >= form.sentryTitles.length) return;
            root.sentryChoice = index - 1;
            root.sentrySelectionMade = true;
            root.selectionChanged = true;
        }
    }
    Connections { target: form.submitControl; function onClicked() { root.submit(); } }
}
