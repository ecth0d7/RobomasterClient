import QtQuick

// 保留界面直接复用既有HUD、面板与贴图，不创建另一份可能逐渐分叉的26版素材。
// 此入口只由独立的参考引擎加载；DesignerPreview的服务和遥测均为本窗口mock。
DesignerPreview {
    title: "RMUC 2026 选手端保留界面 · 离线预览"
    previewCaption: "RMUC 2026 保留界面 · MOCK离线预览 · 非实机数据"
    previewCaptionAlwaysVisible: true
    scenario: "nominal"
    panel: "none"
}
