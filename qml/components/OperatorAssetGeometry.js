.pragma library

// 肖像底部的斜底座具有共同脚印，而 PNG 外框的宽高不同。
// 先把脚印贴到底板主体 (红 112..317 / 蓝 95..299, y=158)，
// 再按底板统一缩放；不能让 PreserveAspectFit 独立居中每张图。
function rosterPortrait(team, kind) {
    const red = {
        hero: [272, 205, 69, 269, 203],
        engineer: [355, 203, 70, 270, 201],
        soldier: [307, 187, 60, 260, 185],
        airplane: [191, 120, 44, 179, 116]
    };
    const blue = {
        hero: [279, 216, 3, 203, 214],
        engineer: [367, 215, 92, 292, 213],
        soldier: [320, 196, 54, 254, 194],
        airplane: [188, 120, 8, 143, 116]
    };
    const data = (team === "blue" ? blue : red)[kind];
    const footprintLeft = team === "blue" ? 95 : 112;
    const footprintWidth = team === "blue" ? 204 : 205;
    const scale = footprintWidth / (data[3] - data[2]);
    return {width: data[0] * scale, height: data[1] * scale,
            x: footprintLeft - data[2] * scale, y: 158 - data[4] * scale};
}

// 来自项目内独立原图的像素测量。透明画布与数码白色主体分开记录，
// 不修改位图，也不借用含固定数字的 UI 整图。
function rosterNumber(team, number) {
    const red = {
        1: [53, 69, 7, 21, 25], 2: [58, 70, 6, 22, 32],
        3: [57, 70, 5, 22, 31], 4: [57, 69, 10, 21, 26],
        5: [57, 69, 4, 21, 32], 6: [64, 112, 6, 56, 33]
    };
    const blue = {
        1: [51, 69, 21, 21, 18], 2: [59, 70, 20, 22, 32],
        3: [59, 70, 20, 22, 31], 4: [60, 69, 21, 21, 31],
        5: [59, 69, 21, 21, 31], 6: [64, 107, 26, 53, 30]
    };
    const data = (team === "blue" ? blue : red)[number];
    // 两队 1–6 号数码的白色主体均为 36 像素高，连接装饰长度不同。
    return data ? {width: data[0], height: data[1], glyphX: data[2], glyphY: data[3],
                   glyphWidth: data[4], glyphHeight: 36} : null;
}

// 202607手册p03与完整底板共用的槽坐标；填充和数值不可各用一套偏移。
function rosterSlots(team) {
    const blue = team === "blue";
    // 原灰槽的两条斜边略有不同，四角独立记录，不能用统一height/2替代。
    return {healthX:blue ? 8 : 122,healthY:174,healthWidth:279,healthHeight:16,
            healthTopLeft:blue ? 10 : 0,healthTopRight:blue ? 279 : 269,
            healthBottomLeft:blue ? 0 : 10,healthBottomRight:blue ? 269 : 279,
            numberX:blue ? 355 : 49,numberY:131,levelX:blue ? 64 : 347,levelBottom:154};
}

// 原等级图片画布和透明余量各不相同。白色字面的宽度／底线统一，
// 1–4级逐杠向上增长，5级起保留原星形，不拉伸成同一个图片盒子。
function rosterLevel(level) {
    const glyphs = {
        1:[32,26,5,2,21,14],2:[32,33,5,3,21,20],3:[32,34,5,2,21,24],4:[32,34,5,2,21,25],
        5:[36,35,6,2,24,24],6:[30,36,6,2,18,28],7:[30,36,5,2,19,28],
        8:[30,36,6,2,18,29],9:[30,36,5,2,19,29],10:[30,36,5,2,19,29]
    };
    const data = glyphs[level];
    if (!data) return null;
    return {width:data[0],height:data[1],glyphX:data[2],glyphY:data[3],glyphWidth:data[4],glyphHeight:data[5]};
}
