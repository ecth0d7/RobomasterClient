.pragma library
function audit(profile, context, view) {
    const p=profile??{},c=context??{},rows=[];
    function add(title,state,detail){rows.push({title,state,detail});}
    add("规则资料",p.document_status==="formal"?"资料已核实":"待核实",(p.rules_document_id??"未提供")+" · "+(p.rules_version??"无版本"));
    const same=c.id===p.id;
    add("当前会话范围",same?"一致":"仅查看参考",same?"界面查看与当前配置一致":"查看该版本不会切换会话，也不会获得此赛季权限");
    const compatible=same && c.wire_compatible===true && p.official_transport_ready===true;
    add("官方线路",compatible?"已有适配器":"待接入",compatible?"当前编解码器 "+c.codec_id+"；实际收发另看链路诊断":"规则已发布不等于字段可解码。当前 codec："+(c.codec_id??"未提供")+"；不套用旧赛季字段");
    add("坐标标定",p.field?.coordinate_mapping_verified===true?"目录已确认":"待标定",(p.field?.frame_id??"未提供参考系")+"；尺寸相同不能证明原点与方向一致");
    const constraints=p.constraints??{};
    add("共享部署",constraints.wired_only?"需核对有线环境":"按配置核对",constraints.wired_only?"按所选赛季规则的操作间有线边界部署；此审计不检测物理网络、不开连接":"不从插件可启动推断比赛部署已合规");
    add("视觉与建议",view?.schema==="rm.situation.view/1"?"宿主有输出":"尚无输出","输出只证明当前服务有快照，不证明定位精度、模型依据或语音已经可听");
    return {rows,ready:compatible,profileId:p.id??"",capabilities:(p.capabilities??[]).slice(0,32),documents:(p.documents??[]).slice(0,16)};
}
