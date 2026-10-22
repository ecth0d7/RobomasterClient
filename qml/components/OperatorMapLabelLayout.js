.pragma library

// 仅做屏幕空间排版：锚点从不移动，不融合观测，不改写米制坐标或地图命令。
function overlaps(a,b,gap) {
    return a.x < b.x+b.w+gap && a.x+a.w+gap > b.x
        && a.y < b.y+b.h+gap && a.y+a.h+gap > b.y;
}
function contains(rect,x,y) {
    return x >= rect.x && x <= rect.x+rect.w && y >= rect.y && y <= rect.y+rect.h;
}
function endPoint(anchor,rect) {
    return {x:Math.max(rect.x,Math.min(rect.x+rect.w,anchor.x)),
        y:Math.max(rect.y,Math.min(rect.y+rect.h,anchor.y))};
}
function intersects(a,b,rect) {
    // Liang–Barsky，含端点；没有浮点采样步长造成的漏穿细标签。
    let low=0,high=1;
    const dx=b.x-a.x,dy=b.y-a.y;
    const p=[-dx,dx,-dy,dy],q=[a.x-rect.x,rect.x+rect.w-a.x,a.y-rect.y,rect.y+rect.h-a.y];
    for (let i=0;i<4;++i) {
        if (p[i] === 0) {if (q[i] < 0) return false;continue;}
        const t=q[i]/p[i];
        if (p[i] < 0) low=Math.max(low,t);else high=Math.min(high,t);
        if (low > high) return false;
    }
    return true;
}
function layout(signature,obstacles,width,height,badgeWidth,badgeHeight,gap,leaderLimit,memory) {
    const markers=JSON.parse(signature),points=[],anchors=[],labels=[];
    for (const marker of markers) points.push({key:marker.key,source:marker.source,sourceIndex:marker.sourceIndex,
        x:marker.x/28*width,y:(1-marker.y/15)*height,text:marker.text,priority:marker.priority});
    // 先已接纳的优先级，再来源键；不让本机顺序、年龄或数组翻转挤掉队友高优先级项。
    points.sort((a,b) => b.priority-a.priority || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
    // 同优先级按来源机器人轮转，避免一个来源的多条观察独占紧凑地图字牌。
    // 每个桶内部仍按完整观测键；这只是阅读顺序，不是来源融合或信任提升。
    for (let priority=3;priority>=0;--priority) {
        const groups=[];
        for (const point of points.filter(item => item.priority === priority)) {
            let group=groups.find(item => item.source === point.source);
            if (!group) {group={source:point.source,items:[]};groups.push(group);}
            group.items.push(point);
        }
        groups.sort((a,b) => a.source < b.source ? -1 : a.source > b.source ? 1 : 0);
        for (let round=0;round<points.length;++round)
            for (const group of groups) if (round < group.items.length) anchors.push(group.items[round]);
    }
    const margin=gap,bounds={x:margin,y:margin,w:width-2*margin,h:height-2*margin};
    const blocked=obstacles.concat(anchors.map(point => ({x:point.x-gap,y:point.y-gap,w:2*gap,h:2*gap})));
    const sizeKey=JSON.stringify([width,height,badgeWidth,badgeHeight,gap,leaderLimit]);
    const previous=memory.sizeKey === sizeKey ? memory.labels : [];
    memory.sizeKey=sizeKey;
    if (bounds.w < badgeWidth || bounds.h < badgeHeight) {
        memory.labels=[];
        return {anchors:anchors,labels:labels,hiddenCount:anchors.length};
    }
    for (const anchor of anchors) {
        const candidates=[];
        function add(x,y) {
            candidates.push({x:Math.max(bounds.x,Math.min(bounds.x+bounds.w-badgeWidth,x)),
                y:Math.max(bounds.y,Math.min(bounds.y+bounds.h-badgeHeight,y)),w:badgeWidth,h:badgeHeight});
        }
        // 先列附近八向，再列全图网格；后者只作密集情况下的有界空位候选。
        for (let ring=1;ring<=3;++ring) {
            const dx=ring*(badgeWidth/2+gap*2),dy=ring*(badgeHeight/2+gap*2);
            for (const direction of [[1,-1],[-1,-1],[1,0],[-1,0],[0,-1],[0,1],[1,1],[-1,1]])
                add(anchor.x+direction[0]*dx-badgeWidth/2,anchor.y+direction[1]*dy-badgeHeight/2);
        }
        for (let y=bounds.y;y<=bounds.y+bounds.h-badgeHeight;y+=badgeHeight+gap*2)
            for (let x=bounds.x;x<=bounds.x+bounds.w-badgeWidth;x+=badgeWidth+gap*2) add(x,y);
        const old=previous.find(label => label.key === anchor.key);
        let retained=null;
        if (old) {
            const x=anchor.x+old.x-old.anchor.x,y=anchor.y+old.y-old.anchor.y;
            if (x >= bounds.x && y >= bounds.y && x+badgeWidth <= bounds.x+bounds.w && y+badgeHeight <= bounds.y+bounds.h) {
                retained={x:x,y:y,w:badgeWidth,h:badgeHeight};
                candidates.unshift(retained);
            }
        }
        let best=null,bestCost=Infinity;
        for (const candidate of candidates) {
            if (blocked.some(rect => overlaps(candidate,rect,gap)) || labels.some(label => overlaps(candidate,label,gap))) continue;
            const end=endPoint(anchor,candidate),dx=end.x-anchor.x,dy=end.y-anchor.y;
            const distance=dx*dx+dy*dy;
            // 紧凑地图不以跨图长线换取塞下所有字牌；未排下数量必须由调用方明示。
            if (distance > leaderLimit*leaderLimit) continue;
            let cost=distance;
            // 引线位于官方图标之下；优先选不穿过其他图标或标签的候选。
            for (const rect of obstacles)
                if (!contains(rect,anchor.x,anchor.y) && intersects(anchor,end,rect)) cost+=width*width;
            for (const label of labels) {
                if (intersects(anchor,end,label)) cost+=width*width;
                if (intersects(label.anchor,label.end,candidate)) cost+=width*width;
            }
            // 旧偏移仍无遮挡时保留方向；不能为保留位置而穿过新的图标或文字框。
            if (candidate === retained && cost === distance) {
                best=Object.assign({},candidate,{end:end});break;
            }
            if (cost < bestCost) {bestCost=cost;best=Object.assign({},candidate,{end:end});}
        }
        if (best) labels.push(Object.assign(best,{key:anchor.key,sourceIndex:anchor.sourceIndex,text:anchor.text,anchor:anchor}));
    }
    memory.labels=labels;
    // 无可读空位时不重叠/缩字；所有锚点保留，调用方明确提示未排下的标签数量。
    return {anchors:anchors,labels:labels,hiddenCount:anchors.length-labels.length};
}
