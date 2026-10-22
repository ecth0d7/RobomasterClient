.pragma library

// 本合同只接宿主已经接纳的完整renderer视图，不解析网络报文或给报文授信。
// UI的到期绘制不能替代宿主单调时钟、认证、撤回tombstone与会话屏障。
const kinds = ["official_player_client","local_sensor","local_vision","derived"];
function token(value) { return typeof value === "string" && value.trim().length > 0 && value.length <= 128 && !/[\x00-\x1f\x7f]/.test(value); }
function integer(value, low, high) { return Number.isSafeInteger(value) && value >= low && value <= high; }
function robot(value) { return Number.isInteger(value) && value > 0 && value < 110 && [1,2,3,4,5,6,7,8,9].includes(value % 100); }
function sameTeam(a,b) { return robot(a) && robot(b) && (a > 100) === (b > 100); }
function key(item) { return JSON.stringify([item?.source_node,item?.source_session_id,item?.source_id,item?.item_id]); }
function text(value) { return typeof value === "string" && value.length ? value : "未提供"; }
function age(ms) { return ms < 1000 ? Math.floor(ms) + "ms" : (ms / 1000).toFixed(1) + "s"; }
function confidence(value) { return value === null ? "置信—" : Math.round(value * 100) + "%"; }
function kind(value) { return ({official_player_client:"选手端转述",local_sensor:"电控感知",local_vision:"视觉",derived:"推导"})[value] ?? "未知来源"; }

function viewReason(view, channel, available, context, receiver, now, previewOnly) {
    if (!view) return "未提供显示视图";
    if (!available) return channel === "local" ? "本机显示源未接通" : "队伍显示源不可用";
    if (!robot(receiver) || !token(context?.session_id)) return "当前接收会话未提供";
    if (view.version !== 1 || view.channel !== channel || view.receiver_robot !== receiver
        || view.session_id !== context.session_id) return "版本、接收身份或会话不匹配";
    if (!token(view.view_id) || !integer(view.revision,0,2147483647)
        || view.revision !== context[channel + "_revision"]) return "显示视图修订不匹配";
    if (typeof view.mock !== "boolean") return "来源模拟标记未提供";
    if (view.mock === true) {
        if (!previewOnly || view.validation !== "mock") return "生产界面拒绝mock";
    } else if (view.validation !== "host_verified") return "宿主接纳边界未核验";
    if (channel === "team" && (!["team_id","match_id","team_epoch","team_issuer_id"].every(name => token(context[name]) && view[name] === context[name])))
        return "队伍、比赛、发布者或epoch不匹配";
    if (view.clock_basis !== "host_epoch_ms" || !integer(view.published_at_ms,0,Number.MAX_SAFE_INTEGER)
        || !integer(view.ttl_ms,1,60000) || now < view.published_at_ms
        || now >= view.published_at_ms + view.ttl_ms) return "视图时间缺失、未来或过期";
    if (!Array.isArray(view.items) || view.items.length > 64 || !Array.isArray(view.markers) || view.markers.length > 64)
        return "显示视图结构或容量不符";
    return "";
}

function itemReason(item, view, receiver, now, previewOnly, playerConnected) {
    if (!item || typeof item !== "object") return "发现项格式无效";
    if (!["item_id","source_node","source_session_id","source_id","producer_version","data_type"].every(name => token(item[name]))
        || !integer(item.revision,0,2147483647) || !sameTeam(item.source_robot,receiver) || !kinds.includes(item.source_kind)) return "来源或标识不完整";
    if (view.channel === "local" && item.source_robot !== receiver) return "本机视图来源机器人不匹配";
    if (view.channel === "team" && item.source_robot === receiver) return "本机转述不重复绘制";
    if (item.mock !== view.mock || (item.mock === true ? !previewOnly || item.validation !== "mock" : item.validation !== "host_verified")) return "发现项接纳状态不匹配";
    if (item.source_kind === "official_player_client" && (!token(item.player_export_id)
        || view.channel === "local" && item.requires_player_client !== true)) return "选手端出处或本机链路依赖未提供";
    if (["local_sensor","local_vision"].includes(item.source_kind) && !token(item.sensor_id)) return "传感器出处未提供";
    if (item.source_kind === "derived" && (!token(item.algorithm_id) || !Array.isArray(item.dependencies) || item.dependencies.length === 0
        || item.dependencies.length > 16 || !item.dependencies.every(token))) return "推导依赖未提供";
    if (typeof item.requires_player_client !== "boolean" || item.requires_player_client && !playerConnected) return "所需选手端链路不可用";
    if (item.lifecycle !== "active") return ({expired:"发现已过期",withdrawn:"发现已撤回",retracted:"发现已撤回",conflict:"发现冲突隔离",unverified:"来源未核验"})[item.lifecycle] ?? "生命周期未提供";
    if (item.state !== "fresh") return "发现字段不是新鲜状态";
    if (!token(item.unit) || typeof item.spatial !== "boolean" || typeof item.summary !== "string" || item.summary.trim().length === 0 || item.summary.length > 512
        || !["validated","unverified"].includes(item.measurement_validation) || !integer(item.priority,0,3)) return "摘要、测量状态或优先级无效";
    if (item.confidence !== null && (typeof item.confidence !== "number" || !Number.isFinite(item.confidence) || item.confidence < 0 || item.confidence > 1)) return "置信度无效";
    if (item.clock_basis !== "host_epoch_ms" || !token(item.source_clock_domain)
        || !integer(item.source_time_ms,0,Number.MAX_SAFE_INTEGER) || !integer(item.produced_at_ms,0,Number.MAX_SAFE_INTEGER)
        || !integer(item.received_at_ms,0,Number.MAX_SAFE_INTEGER) || !integer(item.ttl_ms,1,60000)
        || !integer(item.fresh_for_ms,1,item.ttl_ms) || item.produced_at_ms > item.received_at_ms
        || item.received_at_ms > view.published_at_ms || item.received_at_ms > now) return "时钟映射或原始时间无效";
    if (now < item.produced_at_ms || now >= item.produced_at_ms + Math.min(item.ttl_ms,item.fresh_for_ms)) return "发现独立时效已过期";
    return "";
}

function markerReason(marker, item, context, now) {
    if (marker?.observation_key !== key(item) || marker.observation_revision !== item.revision || item.spatial !== true
        || marker.observation_frame_id !== item.frame_id || marker.observation_frame_revision !== item.frame_revision
        || !token(item.frame_id) || !token(item.frame_revision)) return "地图与观测版本或原坐标不匹配";
    if (marker.lifecycle !== "active" || marker.state !== "fresh" || marker.frame_id !== "rm2026.field"
        || !token(marker.frame_revision) || marker.unit !== "m" || !token(marker.transform_id)
        || marker.transform_validation !== (item.mock === true ? "mock" : "host_verified")) return "地图投影或标定未核验";
    if (!token(context?.field_frame_revision) || marker.frame_revision !== context.field_frame_revision
        || !token(marker.transform_revision) || marker.transform_revision !== context.transform_revisions?.[marker.transform_id]) return "地图或标定版本已变更";
    if (typeof marker.x !== "number" || !Number.isFinite(marker.x) || marker.x < 0 || marker.x > 28
        || typeof marker.y !== "number" || !Number.isFinite(marker.y) || marker.y < 0 || marker.y > 15) return "坐标不在已定义赛场范围";
    if (!integer(marker.transform_produced_at_ms,0,Number.MAX_SAFE_INTEGER) || !integer(marker.transform_ttl_ms,1,60000)
        || marker.transform_produced_at_ms > now || now >= marker.transform_produced_at_ms + marker.transform_ttl_ms) return "坐标转换已过期";
    return "";
}

function channel(view, scope, available, context, receiver, now, previewOnly, playerConnected) {
    const result={active:[],markers:[],history:[],status:""};
    result.status=viewReason(view,scope,available,context,receiver,now,previewOnly);
    const items=Array.isArray(view?.items) ? view.items.slice(0,64) : [];
    const counts={};
    for (const item of items) counts[key(item)]=(counts[key(item)] ?? 0)+1;
    for (const item of items) {
        const reason=result.status || (counts[key(item)] > 1 ? "同源观测重复或版本冲突，等待宿主解决" : itemReason(item,view,receiver,now,previewOnly,playerConnected));
        const source=item && typeof item === "object" && !Array.isArray(item) ? item : {};
        const row=Object.assign({},source,{display_reason:reason,display_channel:scope,display_view_id:view?.view_id,display_view_revision:view?.revision});
        row.summary=typeof source.summary === "string" && source.summary.trim().length ? source.summary.slice(0,512) : "格式异常的发现项";
        if (!reason) {
            row.source_age_ms=now-item.produced_at_ms;row.receive_age_ms=now-item.received_at_ms;
            row.display_remaining_ms=Math.max(0,Math.min(item.produced_at_ms+item.ttl_ms,item.produced_at_ms+item.fresh_for_ms,view.published_at_ms+view.ttl_ms)-now);
            const candidates=view.markers.filter(marker => marker?.observation_key === key(item));
            row.map_projection=candidates.length === 1 ? candidates[0] : null;
            row.map_reason=candidates.length > 1 ? "同观测地图投影重复" : candidates.length === 0 ? "未提供地图投影" : markerReason(candidates[0],item,context,now);
            if (!row.map_reason) result.markers.push(Object.assign({},candidates[0],{renderable:true,validated_for_ui:true,
                source_robot:item.source_robot,source_kind:item.source_kind,mock:item.mock,item_id:item.item_id,
                display_priority:item.priority,
                display_channel:scope,display_view_id:view.view_id,display_view_revision:view.revision,
                label:({local_vision:"视",local_sensor:"感",derived:"推",official_player_client:"转"})[item.source_kind],
                description:description(row)}));
            result.active.push(row);
        }
        result.history.push(row);
    }
    return result;
}

function project(localView, teamView, localAvailable, teamAvailable, context, receiver, now, previewOnly, playerConnected) {
    const local=channel(localView,"local",localAvailable,context,receiver,now,previewOnly,playerConnected);
    const team=channel(teamView,"team",teamAvailable,context,receiver,now,previewOnly,playerConnected);
    // 这里只组合两个已提交renderer通道供人查看，绝不形成AI输入或合并原遥测。
    const active=local.active.concat(team.active).sort((a,b) => b.priority-a.priority || b.produced_at_ms-a.produced_at_ms);
    const markers=local.markers.concat(team.markers).sort((a,b) => b.display_priority-a.display_priority
        || (a.observation_key < b.observation_key ? -1 : a.observation_key > b.observation_key ? 1 : 0));
    return {active:active,markers:markers.slice(0,16),history:local.history.concat(team.history),
        local_status:local.status,team_status:team.status};
}

function description(item) {
    if (!item || !token(item.item_id)) return "没有有效发现。";
    return (item.mock === true ? "离线mock；非真实传感器或队友。\n" : "宿主接纳的独立观察；不作为机器人命令。\n")
        + text(item.summary) + "\n" + item.source_robot + "号 · " + kind(item.source_kind) + " · " + confidence(item.confidence)
        + " · 测量" + (item.measurement_validation === "validated" ? "已核验" : "未核验")
        + "\n节点 " + text(item.source_node) + " / 来源 " + text(item.source_id) + " / 传感器 " + text(item.sensor_id)
        + "\n生产者版本 " + text(item.producer_version) + " / 原选手端 " + text(item.player_export_id)
        + "\n推导算法 " + text(item.algorithm_id) + " / 依赖 " + (Array.isArray(item.dependencies) ? item.dependencies.slice(0,16).join(", ") : "未提供")
        + "\n观测 " + text(item.item_id) + " / v" + item.revision + " / 源会话 " + text(item.source_session_id)
        + "\n原产生时刻 " + item.source_time_ms + "（" + text(item.source_clock_domain) + "）；宿主映射 " + item.produced_at_ms
        + "；接收 " + item.received_at_ms + "；TTL " + item.ttl_ms + "ms"
        + "\n" + (item.display_channel === "local" ? "本机独立" : "队伍完整视图") + " " + text(item.display_view_id) + " / v" + item.display_view_revision
        + "\n" + (item.display_reason || "HUD有效；" + (item.map_reason || "独立二维投影可用"))
        + "\n身份接纳不等于测量准确；QML不执行认证、时钟同步或冲突仲裁。";
}
