import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    objectName: "visionIdentitySetup"
    property var host: null
    property bool editable: false
    property string configurationFile: ""
    property string modelFile: ""
    property var initial: ({})
    property string feedback: ""
    signal saved(string file)
    spacing: 8

    function load() {
        initial = host?.identityConfiguration(configurationFile) ?? {};
        enabledIdentity.checked = initial.enabled === true;
        identityModel.text = String(initial.model_file ?? "");
        confidence.text = String(initial.confidence ?? .65);
        minimumHits.text = String(initial.minimum_hits ?? 3);
        feedback = "";
    }
    readonly property string formError: {
        if (enabledIdentity.checked && !identityModel.text.trim().startsWith("/"))
            return "请填写已有RP26装甲ONNX模型的绝对路径。";
        const score = Number(confidence.text), hits = Number(minimumHits.text);
        if (!confidence.text.trim() || !Number.isFinite(score) || score < .5 || score > 1)
            return "置信度阈值须在0.5至1之间。";
        if (!minimumHits.text.trim() || !Number.isInteger(hits) || hits < 3 || hits > 10)
            return "连续确认帧数须为3至10的整数。";
        return "";
    }
    Component.onCompleted: load()

    OperatorText { Layout.fillWidth: true; text: "身份辅助 · 装甲与整机关联"; size: 16; wrapMode: Text.Wrap }
    OperatorText {
        Layout.fillWidth: true; color: Theme.muted; wrapMode: Text.Wrap
        text: "上方模型仍负责整机检测；这里的装甲模型只提供阵营和编号候选。重叠归属不清、身份矛盾或证据中断时保持未知。需要额外的推理与模型内存。"
    }
    CheckBox {
        id: enabledIdentity; objectName: "enableVisionIdentity"
        text: "启用装甲身份辅助"; palette.windowText: Theme.text; enabled: root.editable
        onToggled: root.feedback = ""
    }
    OperatorText { Layout.fillWidth: true; text: "RP26装甲ONNX模型路径（不是整机模型）"; color: Theme.muted; wrapMode: Text.Wrap }
    OperatorConfigTextField {
        id: identityModel; objectName: "visionIdentityModel"
        Layout.fillWidth: true; enabled: root.editable
        placeholderText: "已有装甲ONNX模型的绝对路径"
        Accessible.name: "身份辅助装甲模型路径"
        onTextEdited: root.feedback = ""
    }
    OperatorText { Layout.fillWidth: true; text: "装甲分类阈值（0.5至1）"; color: Theme.muted; wrapMode: Text.Wrap }
    OperatorConfigTextField {
        id: confidence; objectName: "visionIdentityConfidence"
        Layout.fillWidth: true; enabled: root.editable; Accessible.name: "装甲分类阈值"
        onTextEdited: root.feedback = ""
    }
    OperatorText { Layout.fillWidth: true; text: "连续一致帧数（3至10）"; color: Theme.muted; wrapMode: Text.Wrap }
    OperatorConfigTextField {
        id: minimumHits; objectName: "visionIdentityMinimumHits"
        Layout.fillWidth: true; enabled: root.editable; Accessible.name: "身份连续确认帧数"
        onTextEdited: root.feedback = ""
    }
    OperatorText { Layout.fillWidth: true; visible: root.formError.length > 0; text: root.formError; color: Theme.warning; wrapMode: Text.Wrap }
    Flow {
        Layout.fillWidth: true; spacing: 8
        OperatorButton { text: "从当前JSON读取"; enabled: !!root.host; onClicked: root.load() }
        OperatorButton {
            objectName: "saveVisionIdentity"; text: "保存身份辅助配置"
            enabled: root.editable && root.formError.length === 0 && !!root.host
            onClicked: {
                const values = {enabled: enabledIdentity.checked, model_file: identityModel.text.trim(),
                    confidence: Number(confidence.text), minimum_hits: Number(minimumHits.text)};
                if (root.host.saveIdentityConfiguration(root.configurationFile, values, root.modelFile)) {
                    root.feedback = "已保存完整配置副本。点击上方「应用视觉 / 队内通信配置」后生效；YOLO尚未启动时，还需启用YOLO服务。";
                    root.saved(root.host.configurationFile);
                } else root.feedback = root.host.status;
            }
        }
    }
    OperatorText { Layout.fillWidth: true; visible: root.feedback.length > 0; text: root.feedback; color: Theme.muted; wrapMode: Text.Wrap }
    OperatorText {
        Layout.fillWidth: true; color: Theme.muted; wrapMode: Text.Wrap
        text: root.host?.view?.vision?.identity?.status ?? "身份辅助尚未运行；保存不会自动加载模型。"
    }
}
