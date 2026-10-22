import QtQuick

OperatorExtensionPanelForm {
    id: root
    property var runtime: null
    readonly property string packageId: selectedPackageId
    readonly property string panelId: selectedPanelId
    property string selectedPackageId: ""
    property string selectedPanelId: ""
    property var selectedRuntime: null
    property var selectedContext: null
    property var panelObject: null
    property bool requested: false
    property int requestRevision: 0
    signal libraryRequested
    signal unavailable(string reason)

    // 不保留跨启用代次的上下文；窗口尺寸与鼠标捕获由主界面统一管理。
    function closePanel() {
        const revision = ++requestRevision;
        const creator = selectedRuntime;
        const previousPackage = selectedPackageId;
        const previousPanel = selectedPanelId;
        const owner = panelLoader.item;
        requested = false;
        contentReady = false;
        if (revision !== requestRevision) return;
        // Loader 延后删除 owner；先释放原生单实例登记，允许同一轮立即重开。
        // releasePanel 只接受登记时的 owner，不能借此关闭别处的窗口。
        releaseLease(creator, previousPackage, previousPanel, owner);
        // enabled／visible 回调允许重新导航；旧关闭栈不能清除新请求。
        if (revision !== requestRevision) return;
        panelObject = null;
        panelLoader.active = false;
        if (revision !== requestRevision) return;
        selectedContext = null;
        selectedRuntime = null;
        selectedPackageId = "";
        selectedPanelId = "";
        title = "扩展面板";
        packageCaption = "未选择插件";
        emptyMessage = "从面板库选择已启用插件提供的面板。";
    }
    function invalidate(reason) {
        if (!requested) return;
        // activeChanged 可能从原生退役调用栈到达。立即遮住旧内容，下一轮再释放
        // Loader 的 owner，避免在插件回调／退役栈内销毁其正在执行的 QML。
        const revision = ++requestRevision;
        requested = false;
        contentReady = false;
        if (revision !== requestRevision) return;
        selectedContext = null;
        emptyMessage = reason;
        Qt.callLater(function() {
            if (revision !== root.requestRevision) return;
            root.closePanel();
            root.unavailable(reason);
        });
    }
    function currentEntry() {
        return (runtime?.availablePanels ?? []).find(entry =>
            entry.package_id === selectedPackageId && entry.panel_id === selectedPanelId);
    }
    function contextIsCurrent() {
        return requested && selectedRuntime === runtime && !!selectedContext && selectedContext.active === true
            && typeof runtime?.contextFor === "function"
            && runtime.contextFor(selectedPackageId) === selectedContext && !!currentEntry();
    }
    function openPanel(packageId, panelId) {
        const closeRevision = requestRevision + 1;
        closePanel();
        if (closeRevision !== requestRevision) return;
        selectedPackageId = packageId;
        selectedPanelId = panelId;
        selectedRuntime = runtime;
        requested = true;
        const entry = currentEntry();
        selectedContext = typeof runtime?.contextFor === "function" ? runtime.contextFor(packageId) : null;
        if (!entry || !contextIsCurrent()) {
            invalidate("插件面板当前不可用：请检查插件是否已启用、依赖是否就绪，再从面板库打开。");
            return;
        }
        title = entry.title;
        const installed = (runtime?.packages ?? []).find(row => row.id === packageId);
        packageCaption = (installed?.version ? installed.version + " · " : "") + packageId + " / " + panelId;
        emptyMessage = "正在创建插件面板…";
        const revision = requestRevision;
        Qt.callLater(function() {
            if (revision !== root.requestRevision || !root.requested) return;
            if (!root.contextIsCurrent()) {
                root.invalidate("插件上下文已改变，面板未继续打开。请重新选择当前可用面板。");
                return;
            }
            panelLoader.active = true;
        });
    }
    function releaseLease(creator, packageId, panelId, owner) {
        if (owner && typeof creator?.releasePanel === "function")
            creator.releasePanel(packageId, panelId, owner);
    }
    function attachPanel(owner) {
        if (!owner || !contextIsCurrent()) {
            invalidate("插件上下文已失效，未显示旧面板。");
            return;
        }
        const revision = requestRevision;
        const creator = selectedRuntime;
        const packageId = selectedPackageId;
        const panelId = selectedPanelId;
        const panel = creator.createPanel(packageId, panelId, owner);
        // 插件 Component.onCompleted 可以触发依赖／范围变化；创建后再次确认代次。
        if (revision !== requestRevision || !contextIsCurrent()) {
            releaseLease(creator, packageId, panelId, owner);
            return;
        }
        if (!panel) {
            invalidate("插件面板创建失败：" + (runtime.status || "面板入口无效、已有实例或依赖已变化。"));
            return;
        }
        panelObject = panel;
        panel.parent = owner;
        if (revision !== requestRevision || !contextIsCurrent()) {
            releaseLease(creator, packageId, panelId, owner);
            return;
        }
        panel.anchors.fill = owner;
        if (revision !== requestRevision || !contextIsCurrent()) {
            releaseLease(creator, packageId, panelId, owner);
            return;
        }
        contentReady = true;
        if (revision === requestRevision && contextIsCurrent()) forceActiveFocus();
    }
    onRuntimeChanged: if (requested) invalidate("插件宿主已更换，请从面板库重新打开。")
    onVisibleChanged: if (!visible) closePanel()
    onCloseRequested: closePanel()

    Loader {
        id: panelLoader
        parent: root.contentContainer
        anchors.fill: parent
        active: false
        visible: root.contentReady
        sourceComponent: Item { clip: true }
        onLoaded: root.attachPanel(item)
    }
    Connections {
        target: root.runtime
        function onChanged() {
            if (root.requested && !root.contextIsCurrent())
                root.invalidate("插件已停用、必需依赖失效或当前范围已变化；面板已关闭。");
        }
    }
    Connections {
        target: root.selectedContext
        function onActiveChanged() {
            if (root.requested && root.selectedContext?.active !== true)
                root.invalidate("插件运行上下文已退役；旧面板已关闭，可用时请重新打开。");
        }
    }
    Connections {
        target: root.libraryControl
        function onClicked() { root.closePanel(); root.libraryRequested(); }
    }
}
