.pragma library

// 仅离线样例：官方RMUC2026全国赛V2.2.0 p26/p30/p92–95。
// 生产上限必须取RobotStaticStatus.max_health，不能调用本样例去猜敌方／替换真实遥测。
var heroMelee=[260,300,330,360,400,430,460,500,530,600];
var heroRanged=[200,220,240,260,280,300,320,340,360,400];
var infantryPower=[150,175,200,225,250,275,300,325,350,400];
var infantryHealth=[200,225,250,275,300,325,350,375,400,400];
var thresholds=[0,550,1100,1650,2200,2750,3300,3850,4400,5000];
function sample(id, levelOverride) {
    const role=id%100, blue=id>100;
    const defaults={1:10,3:2,4:8,101:9,103:4,104:7};
    const level=Number.isInteger(levelOverride)?Math.max(1,Math.min(10,levelOverride)):defaults[id]??2;
    if(role===1)return {level:level,maximum:(blue?heroRanged:heroMelee)[level-1],shooter:blue?4:3,chassis:blue?4:3};
    if([3,4,5].includes(role))return {level:level,maximum:(role===4?infantryHealth:infantryPower)[level-1],shooter:1,chassis:role===4?1:2};
    if(role===2)return {maximum:250};
    if(role===7)return {maximum:blue?400:200};
    // 空中以弹量为主，不制造官方全局数组不存在的HP。
    return {level:role===6?level:undefined};
}
function experience(level, progress) {
    const index=Math.max(0,Math.min(9,level-1));
    const span=index<9?thresholds[index+1]-thresholds[index]:0;
    const left=Math.round(span*(1-Math.max(0,Math.min(1,progress))));
    return {current:thresholds[index]+span-left,remaining:left};
}
