import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick3D
import QtQuick3D.AssetUtils
import "../../../qml/components" as Client
import "SceneData.js" as Data
import "../../../qml/components/OperatorMapData.js" as MapData
import "RenderPool.js" as Pool
import "RobotVisual.js" as Art

Item {
    id: root
    objectName: "battlefield3DRenderer"
    readonly property var markingMenu: pingMenu
    signal modeRequested(int mode)
    signal pointPicked(real mapX, real mapY)
    readonly property var receivedMarker: MapData.receivedMarker(telemetry,clientID,false)
    property var receivedScreen: null
    function cancelMarking() { pingMenu.close(); }
    function groundPoint(px,py) {
        // 先反投影到场地平面，再反转厘米坐标。2027模型只是底图，发送仍用2026的28×15米坐标。
        const a=view.mapTo3DScene(Qt.vector3d(px,py,0));
        const b=view.mapTo3DScene(Qt.vector3d(px,py,10000));
        const dy=b.y-a.y;
        if (!Number.isFinite(dy) || Math.abs(dy)<.0001) return null;
        const t=-a.y/dy;
        if (!Number.isFinite(t) || t<0) return null;
        const x=(a.x+(b.x-a.x)*t)/100+14;
        const y=7.5-(a.z+(b.z-a.z)*t)/100;
        if (!Number.isFinite(x) || !Number.isFinite(y) || x<0 || x>28 || y<0 || y>15) return null;
        return {x:x,y:y};
    }
    Client.OperatorMapPingMenu {
        id: pingMenu
    }
    property var telemetry: null
    property bool connected: false
    property int clientID: 3
    property var headingItems: []
    property var projectionItems: []
    property var discoveryMarkers: []
    property var fusionView: ({})
    property double fusionReceived: Date.now()
    onFusionViewChanged: fusionReceived=Date.now()
    property real hudScale: 1
    property string selectedKey: ""
    property bool showTrails: true
    property bool showLabels: true
    property real pitch: -55
    property real yaw: -14
    property real zoom: 1
    readonly property real safeTop: 54
    readonly property real footerLineHeight: Math.ceil(mapFontMetrics.lineSpacing)
    readonly property real footerHeight: footerLineHeight * 3 + 10
    readonly property real safeBottom: footerHeight + 8
    readonly property real centreOffset: (safeBottom-safeTop)/2
    property bool customFocus: false
    property vector3d focusWorld: Qt.vector3d(0,159.5,0)
    readonly property vector3d focusLocal: customFocus ? projectFocus(focusWorld,cameraRig.eulerRotation)
        : Qt.vector3d(fieldProjection.centerX,fieldProjection.centerY,0)
    function projectFocus(point, rotation) {
        if (!Number.isFinite(rotation.x)) return Qt.vector3d(0,0,0);
        return cameraRig.mapPositionFromScene(point);
    }
    function fitCurrentView() { zoom=1;customFocus=false; }
    function focusSelected() {
        const r=selectedRecord;
        if (!r) return;
        // 取景中心沿用显示偏移，不将模型高度写回观测数据。
        const b=Art.visual(r.robotId);
        focusWorld=Qt.vector3d(r.sceneX,95+(b.min[1]+b.max[1])/2,r.sceneZ);
        customFocus=true;
        zoom=.35;
    }
    function panCamera(dx,dy) {
        const centre=cameraRig.mapPositionFromScene(customFocus?focusWorld:Qt.vector3d(0,159.5,0));
        const scale=Math.max(.001,camera.horizontalMagnification);
        focusWorld=cameraRig.mapPositionToScene(Qt.vector3d(centre.x-dx/scale,centre.y+dy/scale,centre.z));
        customFocus=true;
    }
    function zoomAroundPoint(x,y,steps) {
        if (!Number.isFinite(steps) || !steps) return;
        const nextZoom=Math.max(.18,Math.min(2.4,zoom*Math.pow(.9,steps)));
        if (nextZoom===zoom) return;
        const beforeScale=camera.horizontalMagnification;
        const offsetX=x-view.width/2,offsetY=y-view.height/2;
        const pointX=camera.x+offsetX/beforeScale,pointY=camera.y-offsetY/beforeScale;
        const centre=cameraRig.mapPositionFromScene(customFocus?focusWorld:Qt.vector3d(0,159.5,0));
        zoom=nextZoom;
        const afterScale=fitMagnification/nextZoom;
        // 正交取景保留鼠标下的场景点；补偿上下工具区不同的留距，不修改观测坐标。
        focusWorld=cameraRig.mapPositionToScene(Qt.vector3d(pointX-offsetX/afterScale,
            pointY+(offsetY+centreOffset)/afterScale,centre.z));
        customFocus=true;
    }
    readonly property var fieldProjection: projectedBounds(cameraRig.eulerRotation)
    readonly property real fitMagnification: Math.min(
        Math.max(1, view.width - 32) / (fieldProjection.width + 80),
        Math.max(1, view.height - safeTop - safeBottom - 16) / (fieldProjection.height + 80))
    function projectedBounds(rotation) {
        // 姿态参数保持绑定依赖；让Qt计算相机坐标，避免手写欧拉旋转次序不一致。
        // 此边界来自模型包围盒，仅用于取景，不参与观测坐标或场地标定。
        if (!Number.isFinite(rotation.x) || !Number.isFinite(rotation.y))
            return {width:3500, height:2200, centerX:0, centerY:0};
        let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
        for (const x of [-1400, 1400]) for (const y of [-31, 350]) for (const z of [-801, 801]) {
            const p = cameraRig.mapPositionFromScene(Qt.vector3d(x, y, z));
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
        }
        return {width:maxX-minX, height:maxY-minY, centerX:(minX+maxX)/2, centerY:(minY+maxY)/2};
    }
    property var allRows: []
    property var currentRows: []
    property var imageObservations: []
    property bool showUncertainty: true
    property string sourceFilter: "all"
    property string nodeFilter: ""
    readonly property var sourceNodes: Array.from(new Set(allRows.reduce((all,r)=>all.concat(r.sourceNodes??[]),[]).concat(imageObservations.map(r=>r.sourceNode)))).sort()
    property var notes: []
    property var history: ({})
    property var segments: []
    property var labels: []
    property var labelPoolState: ({active:0,slots:0,omitted:0})
    property int labelObjectsCreated: 0
    readonly property string labelCoverage: showLabels && labels.length < currentRows.length
        ? " · 标签 " + labels.length + "/" + currentRows.length + "（已避让）" : ""
    property var markerPoolState: ({active:0,slots:0,omitted:0})
    property var trailPoolState: ({active:0,slots:0,omitted:0})
    property int markerObjectsCreated: 0
    property int trailObjectsCreated: 0
    readonly property var renderPoolDetails: ({markers:markerPoolState,trails:trailPoolState,
        marker_objects_created:markerObjectsCreated,trail_objects_created:trailObjectsCreated,
        labels:labelPoolState,label_objects_created:labelObjectsCreated})
    function poolDiagnostics() {
        let visibleMarkers=0,visibleTrails=0,retiredRecords=0;
        for(let i=0;i<markerRepeater.count;i++) {
            const node=markerRepeater.objectAt(i);
            if(node?.visible)visibleMarkers++;
            else if(node && Object.keys(node.record??{}).length)retiredRecords++;
        }
        for(let i=0;i<trailRepeater.count;i++)if(trailRepeater.objectAt(i)?.visible)visibleTrails++;
        return Object.assign({},renderPoolDetails,{visible_markers:visibleMarkers,visible_trails:visibleTrails,
            inactive_marker_records:retiredRecords});
    }
    property bool releasing: false
    function releaseResources() {
        if (releasing) return;
        // Qt 6.11.1通过source变化注销运行时网格；先清空，再让宿主销毁场景。
        cancelMarking();
        releasing=true;
        if (!markerRepeater) return;
        for (let i=0;i<markerRepeater.count;i++) {
            const marker=markerRepeater.objectAt(i);
            if (marker && typeof marker.releaseResources==="function") marker.releaseResources();
        }
    }
    Component.onDestruction: releaseResources()
    property var assetVerifier: typeof uiViewController === "undefined" ? null : uiViewController
    property bool preparedFailed: false
    property bool assetChoiceReady: false
    property int runtimeImportStarts: 0
    PreparedAssetInfo { id: preparedAssets }
    readonly property bool preparedAvailable: preparedAssets.qtVersion === assetVerifier?.qtRuntimeVersion
        && preparedAssets.source.toString().length > 0
        && typeof assetVerifier?.assetsAvailable === "function"
        && assetVerifier.assetsAvailable(preparedAssets.files)
    readonly property bool usePrepared: preparedAvailable && !preparedFailed
    property bool originalAssetFallback: false
    readonly property string assetVariant: usePrepared ? "prepared" : originalAssetFallback ? "original" : "batched"
    readonly property bool sceneUsable: !releasing && (usePrepared ? prepared.status === Loader3D.Ready : field.status === RuntimeLoader.Success)
    readonly property string loadError: !releasing && !usePrepared && field.status === RuntimeLoader.Error ? field.errorString : ""
    readonly property var sourceModel: robots
    readonly property bool viewActive: visible && root.Window.window?.visible === true
        && root.Window.window?.visibility !== Window.Minimized
    readonly property real renderFps: viewActive ? view.renderStats.fps : 0
    readonly property var selectedRecord: currentRows.find(r=>r.key===selectedKey)??null
    readonly property string detailText: selectedRecord ? selectedRecord.label+" · "+sourceName(selectedRecord.kind)
        +" · "+selectedRecord.coordinateFrame+" · ("+selectedRecord.x.toFixed(2)+", "+selectedRecord.y.toFixed(2)+") m · "+Math.max(0,Date.now()-selectedRecord.stamp)+" ms"
        +"\n"+new Date(selectedRecord.stamp).toISOString()+" · "+selectedRecord.source
        +" · 误差 "+(Number.isFinite(selectedRecord.uncertaintyM)?'±'+selectedRecord.uncertaintyM.toFixed(1)+'m（参数估计）':'未提供')+" · 评分 "+selectedRecord.confidenceText
        +" · 朝向 "+(selectedRecord.headingValid?selectedRecord.headingDeg.toFixed(1)+"°":"未知")
        : "选择模型或右侧来源项查看坐标、时间与证据。模型悬浮高度仅为显示偏移。"
    function sourceName(kind) { return ({own:"本机定位",radar:"雷达",local:"本地共享",vision:"视觉估计",fused:"融合估计",sensor:"传感器",annotation:"人工标注",conflict:"冲突候选"})[kind]??kind; }
    function resetCamera(top) {pitch=top?-90:-55;yaw=top?0:-14;fitCurrentView();Qt.callLater(refreshLabels);}
    function refresh() {
        const now=Date.now(),snapshot=Data.collect(telemetry,connected,clientID,projectionItems,headingItems,discoveryMarkers,fusionView,fusionReceived,now);
        allRows=snapshot.rows;notes=snapshot.notes;imageObservations=snapshot.imageObservations??[];
        currentRows=allRows.filter(r=>(!nodeFilter || (r.sourceNodes??[]).includes(nodeFilter)) && (
            sourceFilter==='all' || sourceFilter==='vision' && ['vision','fused'].includes(r.kind)
            || sourceFilter==='position' && ['own','radar','local','sensor'].includes(r.kind)
            || sourceFilter==='conflict' && r.kind==='conflict'));
        if(nodeFilter && !currentRows.length)notes=notes.concat(['筛选节点 '+nodeFilter+' 暂无新鲜地面观测']);
        const keys=new Set(currentRows.map(r=>r.key));
        for(let i=robots.count-1;i>=0;i--)if(!keys.has(robots.get(i).payload.key))robots.remove(i);
        for(const r of currentRows) {
            let index=-1;for(let i=0;i<robots.count;i++)if(robots.get(i).payload.key===r.key){index=i;break;}
            if(index<0)robots.append({payload:r});else robots.set(index,{payload:r});
        }
        markerPoolState=Pool.keyed(markerSlots,currentRows,512);
        const next={},lines=[];
        for(const r of currentRows) {
            let h=history[r.key]??[];h=h.filter(p=>now-p.stamp<=5000 && p.stamp<=now);
            if(!h.length || r.stamp>h[h.length-1].stamp) {
                if(h.length && Math.hypot(r.sceneX-h[h.length-1].x,r.sceneZ-h[h.length-1].y)>600)h=[];
                h=h.concat([{x:r.sceneX,y:r.sceneZ,stamp:r.stamp}]).slice(-12);
            }
            next[r.key]=h;
            if(showTrails && r.kind!=="conflict")for(let i=1;i<h.length;i++) {
                const a=h[i-1],b=h[i],distance=Math.hypot(b.x-a.x,b.y-a.y);
                if(distance>1 && b.stamp-a.stamp<=1200 && lines.length<384)lines.push({x:(a.x+b.x)/2,y:(a.y+b.y)/2,
                    length:distance/100,angle:-Math.atan2(b.y-a.y,b.x-a.x)*180/Math.PI,team:r.team});
            }
        }
        history=next;segments=lines;
        trailPoolState=Pool.indexed(trailSlots,lines,384);
        if(selectedKey && !keys.has(selectedKey))selectedKey="";
        refreshLabels();
    }
    function refreshLabels() {
        const mark=receivedMarker;
        receivedScreen=mark ? view.mapFrom3DScene(Qt.vector3d((mark.x-14)*100,0,(7.5-mark.y)*100)) : null;
        if (!sceneUsable || !showLabels) {
            labels = [];
            labelPoolState = Pool.keyed(labelSlots, [], 14);
            return;
        }
        const placed = [], avoid = [{x:0,y:0,w:width,h:safeTop}, {x:0,y:height-safeBottom,w:width,h:safeBottom}];
        const labelRows = currentRows.slice().sort((a,b) => {
            const rank = r => r.key === selectedKey ? 0 : r.kind === "conflict" ? 1 : r.kind === "vision" ? 2 : 3;
            return rank(a)-rank(b);
        });
        const footprints = new Map();
        for (const r of currentRows) {
            const estimated = ["vision","fused","conflict","annotation"].includes(r.kind);
            const body = Art.visual(r.robotId);
            const detailed = r.headingValid && !estimated;
            const centreY = detailed ? 95+(body.min[1]+body.max[1])/2 : 95;
            const p = view.mapFrom3DScene(Qt.vector3d(r.sceneX,centreY,r.sceneZ));
            const bodyRadius = Math.hypot(Math.max(Math.abs(body.min[0]),Math.abs(body.max[0])),
                (body.max[1]-body.min[1])/2,Math.max(Math.abs(body.min[2]),Math.abs(body.max[2])))+5;
            const radius = (estimated ? 55 : detailed ? bodyRadius : 21) * camera.horizontalMagnification;
            if (p.z > 0 && p.x >= -radius && p.x <= width+radius && p.y >= -radius && p.y <= height+radius)
                footprints.set(r.key, {x:p.x-radius, y:p.y-radius, w:radius*2, h:radius*2});
        }
        const models = Array.from(footprints.values());
        const overlaps = (a,b) => a.x < b.x+b.w+3 && a.x+a.w+3 > b.x && a.y < b.y+b.h+3 && a.y+a.h+3 > b.y;
        for (const r of labelRows) {
            const model = footprints.get(r.key);
            if (!model) continue;
            const text = r.label+" · "+sourceName(r.kind);
            labelMetrics.text = text;
            const w = Math.min(230, Math.ceil(labelMetrics.advanceWidth+14)), h = fontSize+10;
            const centreX = model.x+model.w/2, centreY = model.y+model.h/2;
            const candidates = [
                {x:centreX-w/2,y:model.y-h-6}, {x:centreX-w/2,y:model.y+model.h+6},
                {x:model.x-w-6,y:centreY-h/2}, {x:model.x+model.w+6,y:centreY-h/2}
            ];
            let slot = null;
            for (const c of candidates) {
                const candidate = {x:Math.max(3,Math.min(width-w-3,c.x)),y:c.y,w,h};
                if (candidate.y < safeTop || candidate.y+h > height-safeBottom) continue;
                if (!avoid.concat(models).some(o => overlaps(candidate,o))) { slot=candidate; break; }
            }
            if (slot) {
                avoid.push(slot);
                placed.push(Object.assign(slot,{text,key:r.key,team:r.team,conflict:r.kind === "conflict",
                    anchorX:centreX,anchorY:centreY,anchorInset:Math.min(model.w,model.h)/4}));
            }
            if (placed.length >= 14) break;
        }
        labels = placed;
        // 与模型和轨迹复用同一有界对象池，移动相机时不逐帧重建文字及点击区域。
        labelPoolState = Pool.keyed(labelSlots, placed, 14);
    }
    readonly property var selectedConnector: {
        const label=labels.find(item=>item.key===selectedKey);
        if (!label) return null;
        const endX=Math.max(label.x,Math.min(label.x+label.w,label.anchorX));
        const endY=Math.max(label.y,Math.min(label.y+label.h,label.anchorY));
        const dx=endX-label.anchorX,dy=endY-label.anchorY,distance=Math.hypot(dx,dy);
        // 从显示锚点向外留出主体空间；这只是标签关联，不是轨迹或额外观测。
        const inset=Math.min(distance,label.anchorInset);
        if (distance-inset<4) return null;
        return {x:label.anchorX+dx/distance*inset,y:label.anchorY+dy/distance*inset,
            length:distance-inset,angle:Math.atan2(dy,dx)*180/Math.PI,key:label.key,
            endX:endX,endY:endY};
    }
    readonly property real fontSize: Math.max(13,10.5/Math.max(.1,hudScale))
    TextMetrics { id:labelMetrics; font.family:Client.Theme.fontFamily; font.pixelSize:root.fontSize }
    FontMetrics { id:mapFontMetrics; font.family:Client.Theme.fontFamily; font.pixelSize:root.fontSize }
    ListModel {id:labelSlots;dynamicRoles:true}
    ListModel {id:robots;dynamicRoles:true}
    ListModel {id:markerSlots;dynamicRoles:true}
    ListModel {id:trailSlots;dynamicRoles:true}
    Timer {
        interval: 250; repeat: true
        running: root.viewActive && !root.releasing
        onTriggered: root.refresh()
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() { if (!root.Window.window.active) root.cancelMarking(); }
        function onVisibilityChanged() {
            if (root.viewActive) root.refresh();
        }
    }
    // 缓存重开及最小化恢复先重算时效；不把旧坐标留到下一次250ms显示定时器。
    onViewActiveChanged: { if (!viewActive) cancelMarking(); else if (assetChoiceReady && !releasing) refresh(); }
    onClientIDChanged: cancelMarking()
    onWidthChanged: Qt.callLater(refreshLabels)
    onHeightChanged: Qt.callLater(refreshLabels)
    onPitchChanged: Qt.callLater(refreshLabels)
    onYawChanged: Qt.callLater(refreshLabels)
    onZoomChanged: Qt.callLater(refreshLabels)
    onFocusLocalChanged: Qt.callLater(refreshLabels)
    onSourceFilterChanged: refresh()
    onNodeFilterChanged: refresh()
    onShowLabelsChanged: refreshLabels()
    onShowTrailsChanged: refresh()
    Component.onCompleted: {assetChoiceReady=true;refresh();}
    Rectangle {anchors.fill:parent;color:"#0c171e";border.color:Client.Theme.hudBorder}
    View3D {
        id:view
        objectName:"battlefield3DViewport"
        anchors.fill:parent
        camera:camera
        environment:SceneEnvironment {
            backgroundMode:SceneEnvironment.Color;clearColor:"#0c171e"
            antialiasingMode:SceneEnvironment.MSAA;antialiasingQuality:SceneEnvironment.Medium
        }
        DirectionalLight {eulerRotation:Qt.vector3d(-55,-30,0);brightness:1.2;ambientColor:"#6b7278"}
        DirectionalLight {eulerRotation:Qt.vector3d(-40,150,0);brightness:.65}
        Node {
            id: cameraRig
            eulerRotation: Qt.vector3d(root.pitch, root.yaw, 0)
            OrthographicCamera {
                id: camera
                x: root.focusLocal.x
                y: root.focusLocal.y - root.centreOffset / Math.max(.001, horizontalMagnification)
                z: 4500; clipNear: 10; clipFar: 15000
                horizontalMagnification: root.fitMagnification / root.zoom
                verticalMagnification: horizontalMagnification
            }
        }
        Loader3D {
            id: prepared
            objectName: "preparedFieldAsset"
            active: root.assetChoiceReady && root.usePrepared && !root.releasing
            asynchronous: true
            visible: status === Loader3D.Ready
            source: active ? preparedAssets.source : ""
            scale: Qt.vector3d(100,100,100)
            eulerRotation.y: 180
            onStatusChanged: {
                if (status === Loader3D.Error && !root.releasing) root.preparedFailed = true;
                else if (status === Loader3D.Ready) Qt.callLater(root.refreshLabels);
            }
        }
        RuntimeLoader {
            id:field
            objectName:"rmuc2027FieldAsset"
            source: !root.assetChoiceReady || root.releasing || root.usePrepared ? "" : Qt.resolvedUrl(root.originalAssetFallback ? "../assets/field-2027.glb" : "../assets/field-2027-batched.glb")
            onSourceChanged: if (source.toString().length > 0) root.runtimeImportStarts++
            // 两个资源均以相同的居中Y向上米制坐标表示；批次版已烘焙原层级变换。
            scale:Qt.vector3d(100,100,100)
            eulerRotation.y:180
            onStatusChanged: {
                if (status === RuntimeLoader.Error && !root.releasing && !root.originalAssetFallback)
                    root.originalAssetFallback = true;
                else if (status === RuntimeLoader.Success)
                    Qt.callLater(root.refreshLabels);
            }
        }
        Repeater3D {
            id:markerRepeater
            model:markerSlots
            onObjectAdded: root.markerObjectsCreated++
            RobotMarker {
                required property var payload
                required property bool occupied
                visible:occupied;record:payload
                selected:occupied && payload.key===root.selectedKey;showUncertainty:root.showUncertainty
            }
        }
        Repeater3D {
            id:trailRepeater
            model:trailSlots
            onObjectAdded: root.trailObjectsCreated++
            Model {
                required property var payload
                required property bool occupied
                visible:occupied
                source:"#Cube";position:Qt.vector3d(payload.x??0,58,payload.y??0)
                scale:Qt.vector3d(payload.length??0,.018,.018);eulerRotation.y:payload.angle??0
                materials:DefaultMaterial {diffuseColor:payload.team==="red"?"#db6a77":payload.team==="blue"?"#62a9cf":"#8dd1c4";lighting:DefaultMaterial.NoLighting}
                opacity:.6
            }
        }
    }
    Client.OperatorMapMarker {
        objectName: "map3DReceivedMarker"
        z: 3
        visible: root.receivedMarker!==null && root.receivedScreen!==null && root.receivedScreen.z>0
            && x>=0 && x+width<=root.width && y>=root.safeTop && y+height<=root.height-root.safeBottom
        x:(root.receivedScreen?.x??0)-width/2
        y:(root.receivedScreen?.y??0)-height/2
        mode:root.receivedMarker?.mode??1
        letter:String.fromCharCode(root.receivedMarker?.ascii??0)
        stale:root.receivedMarker?.stale??false
        obstacles:root.labels
        coordinateText:root.receivedMarker ? "回传 ("+root.receivedMarker.x.toFixed(2)+", "+root.receivedMarker.y.toFixed(2)+")" : ""
    }
    MouseArea {
        objectName: "map3DMarkingSurface"
        anchors.fill:parent
        acceptedButtons:Qt.LeftButton|Qt.RightButton
        property point pressPoint
        property point previousPoint
        property bool dragged:false
        property bool panning:false
        property bool held:false
        property var holdGround:null
        pressAndHoldInterval:Client.Theme.mapSignalHoldMs
        onPressAndHold:mouse=>{
            if (dragged || panning) return;
            holdGround=root.groundPoint(mouse.x,mouse.y);
            if (!holdGround) return;
            held=true;pingMenu.openAt(this,mouse.x,mouse.y);
        }
        onPressed:mouse=>{held=false;if(mouse.button===Qt.RightButton)root.cancelMarking();pressPoint=Qt.point(mouse.x,mouse.y);previousPoint=pressPoint;dragged=false;panning=mouse.button===Qt.RightButton;}
        onPositionChanged:mouse=>{
            if(!pressed)return;
            if(held){pingMenu.trackHeld(this,mouse.x,mouse.y);return;}
            if(Math.hypot(mouse.x-pressPoint.x,mouse.y-pressPoint.y)>4)dragged=true;
            if (dragged) {
                if (panning) root.panCamera(mouse.x-previousPoint.x,mouse.y-previousPoint.y);
                else {
                    root.yaw+=(mouse.x-previousPoint.x)*.25;
                    root.pitch=Math.max(-90,Math.min(-20,root.pitch+(mouse.y-previousPoint.y)*.2));
                }
            }
            previousPoint=Qt.point(mouse.x,mouse.y);
        }
        onReleased: mouse => {
            if (held) {
                const mode=pingMenu.finishHeld(),point=holdGround;
                if(mode && point){root.modeRequested(mode);root.pointPicked(point.x,point.y);}
                return;
            }
            if (dragged || panning) return;
            let object = view.pick(mouse.x, mouse.y).objectHit;
            while (object && !object.targetKey) object = object.parent;
            if (object?.targetKey && root.currentRows.some(r => r.key === object.targetKey))
                root.selectedKey = object.targetKey;
        }
        onWheel:wheel=>{
            const delta=wheel.angleDelta.y || wheel.pixelDelta.y;
            if (!delta) {wheel.accepted=false;return;}
            const steps=wheel.angleDelta.y ? delta/120 : delta/100;
            root.zoomAroundPoint(wheel.x,wheel.y,Math.max(-4,Math.min(4,steps)));
            wheel.accepted=true;
        }
    }
    Item {
        x:0;y:root.safeTop;width:root.width;height:Math.max(0,root.height-root.safeTop-root.safeBottom)
        clip:true
        visible:root.selectedConnector!==null
        Rectangle {
            objectName:"map3DSelectedLabelConnector"
            x:root.selectedConnector?.x??0;y:(root.selectedConnector?.y??0)-root.safeTop
            width:root.selectedConnector?.length??0;height:Client.Theme.hudStroke(root.hudScale,false)
            rotation:root.selectedConnector?.angle??0;transformOrigin:Item.Left
            color:Client.Theme.accent;opacity:.6
            Accessible.ignored:true
        }
    }
    Repeater {
        model: labelSlots
        onItemAdded: root.labelObjectsCreated++
        Rectangle {
            required property var payload
            required property bool occupied
            visible: occupied
            x:payload.x??0; y:payload.y??0; width:payload.w??0; height:payload.h??0
            color: root.selectedKey === payload.key ? "#ef203c40" : "#db122028"
            radius: 2
            border.width: root.selectedKey === payload.key ? 2 : 1
            border.color: payload.conflict ? Client.Theme.warning : payload.team === "red" ? "#f47a83" : payload.team === "blue" ? "#78baff" : "#98ddd0"
            Client.OperatorText {anchors.fill:parent;anchors.margins:4;text:parent.payload.text??"";size:root.fontSize;horizontalAlignment:Text.AlignHCenter}
            MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.selectedKey=parent.payload.key }
        }
    }
    Row {
        x:8;y:8;spacing:6
        Client.OperatorButton {objectName:"map3DReset";width:98;height:34;text:"复位视角";onClicked:root.resetCamera(false)}
        Client.OperatorButton {objectName:"map3DFit";width:98;height:34;text:"适应窗口";Accessible.name:"按当前朝向完整显示场地";onClicked:root.fitCurrentView()}
        Client.OperatorButton {objectName:"map3DFocus";width:98;height:34;text:"聚焦目标";enabled:root.selectedRecord!==null;onClicked:root.focusSelected()}
        Client.OperatorButton {objectName:"map3DTop";width:80;height:34;text:"俯视";onClicked:root.resetCamera(true)}
        Client.OperatorButton {width:42;height:34;text:"+";Accessible.name:"放大立体地图";onClicked:root.zoom=Math.max(.18,root.zoom*.9)}
        Client.OperatorButton {width:42;height:34;text:"−";Accessible.name:"缩小立体地图";onClicked:root.zoom=Math.min(2.4,root.zoom/.9)}
    }
    Rectangle {
        x:8;y:root.height-height-8;width:root.width-16;height:root.footerHeight;color:"#dc102027";radius:3
        Client.OperatorText {
            objectName:"map3DCoordinateNotice"
            x:8;y:4;width:parent.width-16;height:root.footerLineHeight;size:root.fontSize;color:Client.Theme.warning
            text:"RMUC 2027模型 · 当前2026数据仅作坐标适配显示 · 未经2027场地标定"
        }
        Client.OperatorText {
            objectName:"map3DObservationDetail"
            x:8;y:root.footerLineHeight+6;width:parent.width-16;height:root.footerLineHeight*2;size:root.fontSize;text:root.detailText
            lineHeight:root.footerLineHeight;lineHeightMode:Text.FixedHeight
            wrapMode:Text.NoWrap;maximumLineCount:2;elide:Text.ElideRight
            Accessible.name:root.detailText
            HoverHandler {id:detailHover}
            ToolTip.visible:detailHover.hovered;ToolTip.text:root.detailText;ToolTip.delay:450
        }
    }
}
