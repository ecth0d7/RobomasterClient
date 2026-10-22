.pragma library

// 帮助描述现有路由边界；不以离线交互代替生产输入／机器人命令验收。
function entries(page, id, preview, routes) {
    const role = id % 100;
    const valid = (id > 0 && id < 10 || id > 100 && id < 110) && [1,2,3,4,5,6,7,8,9].includes(role);
    const viewState = preview ? "离线窗口可操作。" : routes ? "窗口路由已接，生产输入／控制仍待验收。" : "正式全局路由待接线。";
    if (page === 0) return [
        {key:"P", title:"设置", text:"打开设置，再按P关闭；弹层内保留Tab导航。"},
        {key:"Tab", title:"机器人状态", text:(preview || routes ? "HUD按住查看，松开返回；库打开则固定。" : "状态表可从面板库打开；全局Tab待接线。") + "队友静态参数无来源则—。"},
        {key:"`", title:"受伤／模块", text:viewState + "累计伤害与当前模块分开，详情含全部11项。"},
        {key:"H", title:role === 2 ? "工程装配" : role === 6 ? "空中支援" : "兑换／复活", text:viewState + "只打开适用面板，不立即请求动作。"},
        {key:"F12", title:"帮助", text:preview || routes ? "HUD按住查看，松开返回；点击页签固定，Esc关闭。" : "生产F12输入信号尚未接帮助；面板库仍可打开。"},
        {key:"F11", title:"全屏", text:"切换全屏并保留之前普通／最大化状态；弹层Esc先关闭面板。"},
        {key:"Ctrl+Shift+U", title:"界面与面板库", text:"隐藏、恢复HUD区域，重新打开面板；比赛中也可修改本地配置。"},
        {key:"鼠标／Tab", title:"可访问操作", text:"按钮、页签与选择框可聚焦；只在当前面板的范围内解释操作键。"}
    ];
    if (page === 2) return [
        {key:"Ctrl+Shift+I",title:"机器人输入捕获",text:preview ? "本预览仅显示mock输入，不抓取鼠标、不上报。" : "切换持续捕获；面板弹出或失焦暂挂，关闭面板并返回窗口后恢复。Esc打开设置；再次按捕获快捷键彻底退出。"},
        {key:"W A S D",title:"运动按键",text:"仅在宿主允许、连接有效且捕获开启时上报；面板打开或失焦暂挂实际抓取；捕获意向保持，恢复时从中立输入开始。"},
        {key:"Q…B / Ctrl",title:"官方键鼠位图",text:"Q/E/R/F/G/Z/X/C/V/B与Shift/Ctrl属于原始输入位；并不代表本客户端自动实现机器人动作。"},
        {key:"文本／下拉",title:"编辑优先",text:"输入数量或模型配置时，字母键用于编辑；下拉框打开时暂停该面板命令键。"},
        {key:"按住／松开",title:"长按确认",text:"先释放机器人输入捕获，再用英雄K/L或步兵F保持1.2s；松开、关闭、失焦或资格失效取消。"},
        {key:"Y / Enter",title:"显式确认",text:"只确认当前合资格选择；没有选择或映射未核验时停用，重复按键不连续发请求。"},
        {key:"本地调试",title:"配置可修改",text:"模型策略、语音、共享与建议布局可在比赛中修改；保存后应用，连接和身份切换需显式确认。"},
        {key:"来源／旧／—",title:"真实状态",text:"mock与生产分清，未知或旧数据不能当有效建议，也不能替代宿主资格校验。"}
    ];
    if (!valid) return [{key:"身份",title:"尚无合法机器人",text:"先在登录界面选择合法身份。飞镖编号8/108，控制仍须明确授权。"}];
    let rows = [];
    if (role === 1) rows = [{key:"K / L",title:"英雄部署",text:viewState + "K进入、L退出，按住1.2s；读数与能力有效才允许，不改当前同步模式。"}];
    else if (role === 2) rows = [
        {key:"H / Enter",title:"工程开始装配",text:viewState + "H打开；选择难度，再Enter请求开始。当前难度由宿主确认。"},
        {key:"Y / L",title:"工程确认／切页",text:"状态页Y确认；L仅切换选择／状态页，取消操作必须明确确认。"}
    ];
    else if ([3,4,5].includes(role)) rows = [{key:"F",title:"能量机关",text:viewState + "持续1.2s确认；总灯臂数不代表逐臂身份，类型未确认不显示大机关平均环数。"}];
    else if (role === 6) rows = [
        {key:"H",title:"空中支援",text:viewState + "打开／关闭支援面板；关闭不会结束支援。"},
        {key:"Ctrl+1 / 2",title:"支援选择",text:"面板内选择免费／付费，再确认；免费0仍可查看付费选项，优先消耗免费时长。"},
        {key:"N / Enter",title:"结束／确认",text:"支援中N选择结束并打开面板；Enter再确认，提交不代表已执行。"}
    ];
    else if (role === 7) rows = [
        {key:"面板库",title:"哨兵面板入口",text:"从面板库打开；不把S后退键抢作全局姿态命令。"},
        {key:"鼠标选择 / Y",title:"哨兵命令",text:"六姿态与五补给／复活分组；Y确认、N撤销。最新结果无请求ID，不伪造对应关系。"}
    ];
    else rows = [{key:"面板库",title:"雷达位置／标识",text:"本机雷达只读官方位置，不显示哨兵姿态或发送哨兵命令；来源与单位分开。"}];
    rows.push({key:"Ctrl+1…3",title:"兑换面板内",text:"选择当前页项目，Y／Enter确认，N撤销；数量输入优先，未核验参数不请求。"});
    rows.push({key:"J F L / Y N",title:"飞镖云台手权限",text:"从面板库打开，授权后J选目标／F选开闸／L选发射，Y确认N撤销；飞镖8/108亦需明确授权。"});
    rows.push({key:"先选再确认",title:"生产状态",text:preview ? "离线命令仅记录mock意图，机器人／资格／服务尚未验证。" : "控制入口由宿主能力决定；未接通时停用，不宣称按键已控制机器人。"});
    return rows;
}
