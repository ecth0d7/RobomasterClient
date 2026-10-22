import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Routing presentation only. Saving preferences and accepting announcements
// remain in the ordinary wrapper and the native voice coordinator.
Item {
    id: root
    objectName: "terminalVoiceSetupForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias saveControl: saveButton
    property alias undoControl: undoButton
    property alias teamControl: teamField.inputControl
    property alias robotControl: robotSelect
    property alias localEnabledControl: localCheck
    property alias teamEnabledControl: teamCheck
    property alias priorityControl: prioritySelect
    property alias speakerControl: speakerField.inputControl
    property alias listenersControl: listenersInput
    property Component nodeDelegate: null
    property Component announcementDelegate: null
    property int nodeCount: 0
    property int announcementCount: 0
    readonly property real nodeDelegateWidth: teamColumn.width
    readonly property real announcementDelegateWidth: contentColumn.width
    property bool inputEditable: false
    property bool saveEnabled: false
    property bool undoEnabled: false
    property bool localEnabled: false
    property bool teamEnabled: false
    property string teamValue: ""
    property var robotTitles: []
    property int robotIndex: -1
    property string robotDisplayText: "选择2027阵营／角色／槽位"
    property string robotHint: "不推测官方登录编号。"
    property int priorityIndex: -1
    property string priorityDisplayText: "尚未选择优先级"
    property string speakerValue: ""
    property string listenersValue: ""
    property string lockText: "Designer绘制参考 · 尚未接通语音协调宿主。"
    property string statusText: "没有活动语音请求；此Form不保存配置或提交语音。"
    property bool feedbackVisible: false
    property string formErrorText: ""
    property var routingRows: []
    property var grantRows: []
    property real sectionSpacing: 16
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real columnGap: 12
    property real actionSpacing: 12
    property real actionWidth: 190
    property real secondaryActionWidth: 156
    property real controlHeight: 38
    property real labelHeight: 26
    property real labelGap: 4
    property real hintGap: 8
    property real minimumHintHeight: 26
    property real sectionContentMargin: 14
    property real sectionBodyTop: 47
    property real identityBreakpoint: 760
    property real checkWidth: 380
    property real listenersHeight: 110
    property real sectionTitleSize: 14
    property real introSize: 13
    property real labelSize: 12
    property real noteSize: 12
    property real inputSize: 14
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText {
            width: parent.width; height: implicitHeight; size: root.introSize
            color: root.warningColor; font.family: root.fontFamily
            text: "这里只协调通过接纳的有效建议，不生成样例语音或机器人动作。模型面板的语音意向与本页的本机输出许可共同生效。队内模式由唯一指定节点播放，其他节点不因处于接收列表就重复发声。"
            wrapMode: Text.Wrap; elide: Text.ElideNone
        }
        Flow {
            width: parent.width; spacing: root.actionSpacing
            OperatorButton { id: saveButton; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "保存自动语音偏好"; primary: true; enabled: root.saveEnabled; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: undoButton; width: Math.min(root.secondaryActionWidth, parent.width); height: root.controlHeight; text: "撤销未保存修改"; enabled: root.undoEnabled; font.family: root.fontFamily; textColor: root.textColor }
        }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.lockText.length > 0; text: root.lockText; color: root.warningColor; size: root.noteSize; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; text: root.statusText; color: root.feedbackVisible ? root.textColor : root.secondaryTextColor; size: root.noteSize; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorDiagnosticTable { objectName: "terminalVoiceDiagnosticsSection"; width: parent.width; title: "实际自动语音路径"; rows: root.routingRows; fontFamily: root.fontFamily; textColor: root.textColor; mutedColor: root.secondaryTextColor; separatorColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize; titleColor: root.textColor; titleSize: root.sectionTitleSize }
        OperatorSection {
            id: preferencesSection
            objectName: "terminalVoiceRoutingSection"
            width: parent.width
            height: preferencesColumn.implicitHeight + bodyTop + contentMargin
            title: "建议身份与本机语音许可 · 保存后应用"
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: preferencesColumn
                parent: preferencesSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                GridLayout {
                    width: parent.width
                    columns: width >= root.identityBreakpoint ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorStartupFieldForm {
                        id: teamField
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        label: "队伍标识"; value: root.teamValue; hint: "与建议服务和共享身份一致。"; maximumLength: 64; editable: root.inputEditable
                        labelHeight: root.labelHeight; labelGap: root.labelGap; controlHeight: root.controlHeight; hintGap: root.hintGap; minimumHintHeight: root.minimumHintHeight
                        labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.noteSize
                        fontFamily: root.fontFamily; textColor: root.textColor; secondaryTextColor: root.secondaryTextColor; warningColor: root.warningColor; inputBorderColor: root.separatorColor
                    }
                    Item {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        implicitHeight: robotHintText.y + robotHintText.height
                        OperatorText { id: robotLabel; width: parent.width; height: Math.max(root.labelHeight, implicitHeight); text: "本机语义机器人 · 非线路ID"; size: root.labelSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                        OperatorSelect { id: robotSelect; y: robotLabel.height + root.labelGap; width: parent.width; height: root.controlHeight; label: "语音所属机器人"; model: root.robotTitles; currentIndex: root.robotIndex; displayText: root.robotDisplayText; emptyText: root.robotDisplayText; enabled: root.inputEditable; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)); textColor: root.textColor }
                        OperatorText { id: robotHintText; y: robotSelect.y + robotSelect.height + root.hintGap; width: parent.width; height: Math.max(root.minimumHintHeight, implicitHeight + 4); text: root.robotHint; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    }
                }
                Flow {
                    width: parent.width; spacing: root.actionSpacing
                    OperatorCheckBox { id: localCheck; width: Math.min(root.checkWidth, parent.width); height: root.controlHeight; text: "允许本机接收并输出建议语音"; checked: root.localEnabled; enabled: root.inputEditable; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)); textColor: root.textColor }
                    OperatorCheckBox { id: teamCheck; width: Math.min(root.checkWidth, parent.width); height: root.controlHeight; text: "采用队内指定节点统一播放路径"; checked: root.teamEnabled; enabled: root.inputEditable; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)); textColor: root.textColor }
                }
                OperatorSelect { id: prioritySelect; width: parent.width; height: root.controlHeight; label: "最低自动播报优先级"; model: ["一般及以上", "注意及以上", "仅紧急"]; currentIndex: root.priorityIndex; displayText: root.priorityDisplayText; emptyText: root.priorityDisplayText; enabled: root.inputEditable; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)); textColor: root.textColor }
                OperatorText { width: parent.width; height: implicitHeight; text: "关闭队内模式时，本机播报独立工作，不依赖共享插件。开启队内模式后，普通本机路径暂停；队伍不可用或时钟未核验时明确暂停，不隐式恢复本机播报而产生重复声音。"; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: implicitHeight; text: "保存会取消旧播报并撤回本机共享事件；仅处理之后新到达且仍有效的建议，不补播保存前的结果。静音、音量、音色和实际语音服务仍由已有语音面板管理。"; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            id: teamSection
            objectName: "terminalVoiceListenersSection"
            width: parent.width
            height: teamColumn.implicitHeight + bodyTop + contentMargin
            title: "队内播放职责与接收范围"
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: teamColumn
                parent: teamSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorStartupFieldForm {
                    id: speakerField
                    width: parent.width
                    label: "唯一播放节点标识"; value: root.speakerValue; hint: "此节点负责队内声音输出；可填写稍后配置的明确节点ID。"; editable: root.inputEditable
                    labelHeight: root.labelHeight; labelGap: root.labelGap; controlHeight: root.controlHeight; hintGap: root.hintGap; minimumHintHeight: root.minimumHintHeight
                    labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.noteSize
                    fontFamily: root.fontFamily; textColor: root.textColor; secondaryTextColor: root.secondaryTextColor; warningColor: root.warningColor; inputBorderColor: root.separatorColor
                }
                OperatorText { width: parent.width; height: implicitHeight; text: "已配置的可信节点 · 接收列表只定义允许接收的路由／界面范围，不能让其他节点同时播放。指定播放节点必须勾选。"; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                Repeater { model: root.nodeCount; delegate: root.nodeDelegate }
                OperatorText { width: parent.width; height: implicitHeight; text: "接收节点标识 · 每行一个；可先配置明确身份，最多16项，不使用通配符。"; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                ScrollView {
                    id: listenersScroll
                    width: parent.width; height: root.listenersHeight
                    contentWidth: availableWidth
                    clip: true
                    OperatorTextArea { id: listenersInput; width: listenersScroll.availableWidth; height: Math.max(root.listenersHeight, implicitHeight); label: "明确接收节点列表"; enabled: root.inputEditable; text: root.listenersValue; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)); color: root.inputEditable ? root.textColor : root.secondaryTextColor }
                }
                OperatorText { width: parent.width; height: implicitHeight; text: "队内播放须同时通过完整汇总视图、发布者与原来源证明、逐字段voice授权及独立时钟映射核验。当前共享时钟未核验时，队内语音如实不可用；不会把签名或新接收时间当作新鲜测量。"; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            id: grantsSection
            objectName: "terminalVoiceGrantsSection"
            width: parent.width
            height: grantsColumn.implicitHeight + bodyTop + contentMargin
            title: "共享插件所需的精确授权"
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: grantsColumn
                parent: grantsSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText { width: parent.width; height: implicitHeight; text: "各建议源节点可发布自己的有效建议，来源机器人、会话、请求与快照保持可追溯。发布使用本机规范总线中的derived推导事件，不发送机器人命令，也不直接建立额外网络连接。"; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                OperatorDiagnosticTable { width: parent.width; title: "在队内共享面板中逐项授权"; rows: root.grantRows; fontFamily: root.fontFamily; textColor: root.textColor; mutedColor: root.secondaryTextColor; separatorColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize; titleColor: root.textColor; titleSize: root.sectionTitleSize }
                OperatorText { width: parent.width; height: implicitHeight; text: "只共享有效建议的短文本、优先级、请求ID与输入快照ID，不共享API密钥或完整模型输入。取消、撤回、过期、断连或来源变更时协调层按原固定寿命取消语音；重复汇总不续命、不重复提交。"; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            }
        }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.formErrorText.length > 0; text: root.formErrorText; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        Repeater { model: root.announcementCount; delegate: root.announcementDelegate }
    }
}
