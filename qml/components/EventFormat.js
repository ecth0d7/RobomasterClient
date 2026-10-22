.pragma library
.import "UiFormat.js" as UiFormat

// 编号依据 RoboMaster 2026 通信协议 V2.0.0，第 2.2.7 节。
function robotName(id) {
    const value = Number(id), base = value > 100 ? value - 100 : value;
    if (!Number.isInteger(value) || value <= 0) return "未知来源";
    const team = value > 100 ? "蓝方" : "红方";
    if (base === 11) return team + "前哨站";
    if (base >= 1 && base <= 9) return team + UiFormat.role(base);
    return "目标 " + value;
}
function title(id) {
    return ({1:"机器人击毁", 2:"前哨站被摧毁", 3:"大能量机关激活成绩", 4:"能量机关已激活",
        5:"己方英雄狙击伤害", 6:"对方英雄狙击伤害", 7:"对方呼叫空中支援", 8:"对方空中支援被反制",
        9:"飞镖命中", 10:"对方飞镖闸门开启", 11:"基地遭到攻击", 12:"对方前哨站停转",
        13:"对方基地护甲展开", 14:"工程强制退出缓冲", 15:"工程装配结果"})[id] ?? "系统事件 " + id;
}
function parts(param) { return String(param ?? "").split(",").map(function(value) { return value.trim(); }); }
function knownRobot(id,allowOutpost) {
    return Number.isInteger(id) && id>0 && id<=111
        && ([1,2,3,4,5,6,7,8,9].includes(id%100) || allowOutpost && id%100===11);
}
// 只把协议能解释的字段转换为临时画面；无击杀者不补成当前客户端。
function presentation(id,param,receiver) {
    const values=parts(param),first=Number(values[0]);
    const own=receiver>100?"blue":"red",opponent=receiver>100?"red":"blue";
    const result={kind:"text",team:"green",caption:notificationText(id,param),victim:0,killer:0,icon:""};
    if(id===1) {
        if(values.length!==2 || !values.every(v=>/^\d+$/.test(v)) || !knownRobot(first,false))return null;
        const killer=Number(values[1]);
        return Object.assign(result,{kind:"kill",victim:first,killer:knownRobot(killer,true)?killer:0,
            caption:knownRobot(killer,true)?"摧毁":"战亡",team:(knownRobot(killer,true)?killer:first)>100?"blue":"red"});
    }
    if(id===2) {
        if(values.length!==1 || !/^\d+$/.test(values[0]) || ![11,111].includes(first))return null;
        return Object.assign(result,{team:first>100?"blue":"red",caption:(first>100?"蓝方":"红方")+"前哨站被击毁"});
    }
    if(id===3) {
        if(values.length!==2 || !/^\d+$/.test(values[0]) || first>4294967295
            || !values[1].length || !Number.isFinite(Number(values[1])) || Number(values[1])<0)return null;
        return Object.assign(result,{kind:"rune",caption:"大能量机关激活成绩",details:"成功灯臂 "+first+"　平均环数 "+UiFormat.number(Number(values[1]),1),icon:"rune"});
    }
    if(id===4) {
        if(values.length!==1 || !/^\d+$/.test(values[0]) || ![1,2].includes(first))return null;
        return Object.assign(result,{kind:"rune",caption:(first===1?"小":"大")+"能量机关已激活",icon:"rune"});
    }
    if(id===9) {
        if(values.length!==2 || !values.every(v=>/^\d+$/.test(v)) || ![1,2].includes(first) || ![1,2,3,4,5].includes(Number(values[1])))return null;
        return Object.assign(result,{kind:"dart",team:first===1?"red":"blue",caption:description(id,param).replace("命中","飞镖命中"),icon:"dart"});
    }
    if([5,6].includes(id))result.team=id===5?own:opponent;
    if([7,8,10,12,13].includes(id))result.team=opponent;
    if(id===11)result.team=own;
    if([7,10,11,12,13,14].includes(id) && !String(param??"").trim())result.caption=title(id);
    return id>=1 && id<=15?result:null;
}
function description(id, param) {
    const fields = parts(param);
    const first = Number(fields[0]);
    if (id === 1 && fields.length === 2 && fields.every(function(value) { return /^\d+$/.test(value); }))
        return robotName(Number(fields[1])) + " 击毁 " + robotName(first);
    if (id === 2 && /^\d+$/.test(fields[0])) return robotName(first) + "被摧毁";
    if (id === 3) return fields.length === 2 && fields.every(function(value) { return value.length > 0 && Number.isFinite(Number(value)); })
        ? "成功灯臂 " + first + " · 平均环数 " + UiFormat.number(Number(fields[1]), 1)
        : "激活成绩未知 · 参数未提供或未识别";
    if (id === 4) return ({1:"小能量机关", 2:"大能量机关"})[first] ?? "激活类型未知";
    if (id === 5 || id === 6) return "累计狙击伤害 " + (fields[0].length ? UiFormat.number(first) : "—");
    if (id === 8) return "己方剩余反制次数 " + (fields[0].length ? UiFormat.number(first) : "—");
    if (id === 9 && fields.length === 2) {
        const team = ({1:"红方",2:"蓝方"})[first] ?? "未知方";
        const target = ({1:"前哨站",2:"基地固定目标",3:"基地随机固定目标",4:"基地随机移动目标",5:"基地末端移动目标"})[Number(fields[1])] ?? "未知目标";
        return team + "命中" + target;
    }
    // 空字符串不能经Number("")转为0，再被误报为装配成功。
    if (id === 15) return fields.length === 1 && /^\d+$/.test(fields[0])
        ? ({0:"装配成功",1:"能量单元被拔出",2:"装配超时",3:"离开装配区过久",4:"工程战亡",5:"四级协作超时",6:"主动退出",7:"结算未检测到能量单元",8:"强制退出缓冲到期"})[first] ?? "装配结果未知"
        : "装配结果未知 · 参数未提供或未识别";
    return String(param ?? "").length ? "参数 · " + String(param).slice(0,256) : "服务器事件通知";
}
function critical(id) { return [1,2,6,11,14].indexOf(id) !== -1; }

// 无参数事件也必须保留事件名；接收客户端不是击杀者，0或未知击杀者不补造。
function notificationText(id, param) {
    const values=parts(param);
    if(id===1 && values.length===2 && values.every(v=>/^\d+$/.test(v))) {
        const victim=Number(values[0]),killer=Number(values[1]);
        // 已知事件对象也可为飞镖／前哨站，不能把登录身份列表用作事件对象列表。
        const known=killer>0 && killer<=111 && [1,2,3,4,5,6,7,8,9,11].includes(killer%100);
        return known?robotName(killer)+" 摧毁 "+robotName(victim)
            :robotName(victim)+" 战亡 · "+(killer===0?"击杀者未提供":"击杀者未识别");
    }
    if([7,10,11,12,13,14].includes(id) && !String(param??"").trim())return title(id);
    return title(id)+" · "+description(id,param);
}

function notificationTone(id, param, receiver) {
    if(![1,2,3,4,5,6,7,8,9].includes(receiver%100) || receiver<=0 || receiver>=110)return "neutral";
    const values=parts(param),ownBlue=receiver>100;
    if((id===1 && values.length===2 || id===2 && values.length===1)
        && values.every(v=>/^\d+$/.test(v))) {
        const victim=Number(values[0]);
        const known=id===2?[11,111].includes(victim)
            :victim>0&&victim<110&&[1,2,3,4,5,6,7,8,9].includes(victim%100);
        if(known)return (victim>100)===ownBlue?"adverse":"beneficial";
    }
    // 仅对协议明确区分己方／对方、且参数能核对的结果着色；其余保持白色。
    if([5,6].includes(id) && values.length===1 && /^\d+$/.test(values[0]) && Number(values[0])>0)
        return id===5?"beneficial":"adverse";
    if([7,10,11,14].includes(id) && !String(param??"").trim())return "adverse";
    if(id===12 && !String(param??"").trim())return "beneficial";
    if(id===8 && values.length===1 && /^\d+$/.test(values[0]))return "beneficial";
    if(id===9 && values.length===2 && values.every(v=>/^\d+$/.test(v))
        && [1,2].includes(Number(values[0])) && [1,2,3,4,5].includes(Number(values[1])))
        return (Number(values[0])===2)===ownBlue?"beneficial":"adverse";
    if(id===15 && values.length===1 && /^\d+$/.test(values[0])) {
        const result=Number(values[0]);
        return result===0?"beneficial":[1,2,3,4,5,7,8].includes(result)?"adverse":"neutral";
    }
    return "neutral";
}
