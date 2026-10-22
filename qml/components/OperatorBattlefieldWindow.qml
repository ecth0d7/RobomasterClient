import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: root
    property var host: null
    readonly property var view: host?.view ?? ({})
    property bool isometric: false
    property string selectedId: ""
    property string peerNode: ""
    property bool showObservations: false
    readonly property var selectedPeer: (root.view.peer_views ?? []).find(v => v.node_id === root.peerNode)
    readonly property var displayedTracks: root.peerNode.length ? root.selectedPeer?.tracks ?? [] : root.view.tracks ?? []
    onViewChanged: if (root.peerNode.length && !(root.view.peer_views ?? []).some(v => v.node_id === root.peerNode)) root.peerNode = ""
    onDisplayedTracksChanged: synchronizeTracks()
    Component.onCompleted: synchronizeTracks()
    ListModel { id: trackRows }
    function synchronizeTracks() {
        if (!trackRows) return;
        const rows = root.displayedTracks;
        const ids = rows.map(t => t.id);
        for (let i=trackRows.count-1;i>=0;i--) if (!ids.includes(trackRows.get(i).targetId)) trackRows.remove(i);
        for (let i=0;i<rows.length;i++) {
            let current = -1;
            for (let j=0;j<trackRows.count;j++) if (trackRows.get(j).targetId===rows[i].id) { current=j;break; }
            const json=JSON.stringify(rows[i]);
            if (current<0) trackRows.insert(i,{targetId:rows[i].id,rowJson:json});
            else {
                if (current!==i) trackRows.move(current,i,1);
                if (trackRows.get(i).rowJson!==json) trackRows.setProperty(i,"rowJson",json);
            }
        }
    }
    width: 1180
    height: 780
    minimumWidth: 820
    minimumHeight: 600
    title: "战场态势 · 来源与推断"
    color: Theme.background
    Shortcut { sequence: "Escape"; enabled: root.visible; onActivated: root.hide() }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            OperatorText { text: "战场态势"; font.pixelSize: 22; Layout.fillWidth: true }
            OperatorButton { text: root.isometric ? "切换平面" : "切换等距"; onClicked: root.isometric = !root.isometric }
            OperatorButton { text: "关闭窗口"; onClicked: root.hide() }
        }
        OperatorText { Layout.fillWidth: true; text: root.host?.status ?? "可选插件未安装"; color: Theme.muted; wrapMode: Text.Wrap }
        OperatorText {
            Layout.fillWidth: true; color: Theme.muted; wrapMode: Text.Wrap
            text: "UDP整机 " + (root.view.boxes?.length ?? 0) + " · 亮点轨迹候选 " + (root.view.projectile?.tracks?.filter(t=>t.confirmed).length ?? 0)
                + " · 拖影像素 " + (root.view.projectile?.trail_pixels ?? 0)
                + " · 队友视觉 " + (root.view.observations ?? []).filter(o=>o.kind==="vision" && o.origin!==root.view.node_id).length
                + " · " + (root.view.projectile?.status ?? "弹丸跟踪未启用")
        }
        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: configuration
                Layout.fillWidth: true
                placeholderText: "态势配置 JSON 的绝对路径"
                text: root.host?.configurationFile ?? ""
                Accessible.name: "态势配置文件"
                selectByMouse: true
            }
            OperatorButton { text: "加载并启动"; enabled: !!root.host; onClicked: root.host.start(configuration.text) }
            OperatorButton { text: "停止"; enabled: root.host?.active ?? false; onClicked: root.host.disable() }
        }
        RowLayout {
            Layout.fillWidth: true
            OperatorText { Layout.fillWidth: true; text: "模型：" + (root.view.model_status ?? "未启用"); color: Theme.muted; elide: Text.ElideRight }
            OperatorButton { text: "分析当前态势"; enabled: root.host?.active ?? false; onClicked: root.host.analyze(question.text) }
            CheckBox {
                text: "静音"; palette.windowText: Theme.text
                checked: root.view.voice?.muted ?? false
                onToggled: root.host?.mute(checked); Accessible.name: "静音并清空队列"
            }
            OperatorButton { text: "打断播报"; onClicked: root.host?.cancelVoice() }
        }
        OperatorText {
            Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            text: root.view.advice?.text ? "建议（推断） · " + Math.round(root.view.advice.confidence*100) + "% · "
                + new Date(root.view.advice.stamp_ms).toLocaleTimeString() + "：" + root.view.advice.text : "暂无有效模型建议；可关闭模型后独立使用观测、共享与语音。"
        }
        RowLayout {
            Layout.fillWidth: true
            ComboBox {
                id: sceneSelector
                Layout.preferredWidth: 260
                model: ["本机融合"].concat((root.view.peer_views ?? []).map(v => "队友融合 · " + v.node_id))
                currentIndex: root.peerNode.length ? 1+(root.view.peer_views ?? []).findIndex(v => v.node_id === root.peerNode) : 0
                Accessible.name: "态势来源视图"
                onActivated: root.peerNode = currentIndex > 0 ? (root.view.peer_views ?? [])[currentIndex-1]?.node_id ?? "" : ""
            }
            OperatorText {
                Layout.fillWidth: true; color: Theme.muted; wrapMode: Text.Wrap
                text: root.peerNode.length ? "来自 " + root.peerNode + " 的融合推断；不重新当作独立传感器加入本机融合。"
                    : "本机融合已授权的原始观测；队友融合视图单独展示，保留来源与到期时间。"
            }
        }
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal
            Rectangle {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 360
                color: "#18241f"
                border.color: Theme.line
                Canvas {
                    id: map
                    anchors.fill: parent
                    anchors.margins: 20
                    property var tracks: root.displayedTracks
                    onTracksChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Connections { target: root; function onIsometricChanged() { map.requestPaint(); } }
                    function point(p) {
                        const scale = Math.min((width-24)/28, (height-24)/15);
                        const isoScale = Math.min((width-24)/(43*.866), (height-24)/(43*.5));
                        return root.isometric ? ({x: width/2 + ((p[0]-14)-(p[1]-7.5))*.866*isoScale,
                                                  y: height/2 + ((p[0]-14)+(p[1]-7.5))*.5*isoScale})
                                              : ({x:(width-28*scale)/2+p[0]*scale, y:(height+15*scale)/2-p[1]*scale});
                    }
                    onPaint: {
                        const c = getContext("2d"); c.reset();
                        const labels = [];
                        const marked = new Set();
                        function label(text, p) {
                            c.font="12px sans-serif";
                            const w=Math.min(map.width,c.measureText(text).width+6), h=18;
                            for(let n=0;n<12;n++) {
                                const x=Math.max(0,Math.min(map.width-w,p.x+10));
                                const y=p.y-22+n*20;
                                const r={x:x,y:y,w:w,h:h};
                                if(y<0 || y+h>map.height-20 || labels.some(o=>x<o.x+o.w && x+w>o.x && y<o.y+o.h && y+h>o.y))continue;
                                labels.push(r);c.fillText(text,x,y+13,w);return;
                            }
                        }
                        c.strokeStyle = "#40564b"; c.lineWidth = 1;
                        function line(a,b) { const p = map.point(a), q = map.point(b); c.beginPath(); c.moveTo(p.x,p.y); c.lineTo(q.x,q.y); c.stroke(); }
                        for(let x=0;x<=28;x+=2) line([x,0],[x,15]);
                        for(let y=0;y<=15;y+=3) line([0,y],[28,y]);
                        for(const t of map.tracks) {
                            c.strokeStyle = t.team === "red" ? "#fc7568" : t.team === "blue" ? "#5bcefa" : "#f4df6a";
                            c.fillStyle = c.strokeStyle;
                            if(t.conflict) {
                                for(const evidence of t.evidence) {
                                    const p = map.point(evidence.position);
                                    const key=t.id+":"+Math.round(p.x)+":"+Math.round(p.y);
                                    if(marked.has(key))continue;
                                    marked.add(key);
                                    c.strokeRect(p.x-7,p.y-7,14,14);
                                    label(t.id+" 冲突",p);
                                }
                                continue;
                            }
                            const p = map.point(t.position);
                            const trail = t.trail ?? [];
                            c.beginPath();
                            for(let n=0;n<trail.length;n++) {
                                const q = map.point(trail[n].position);
                                if(n===0)c.moveTo(q.x,q.y);else c.lineTo(q.x,q.y);
                            }
                            c.stroke();
                            c.globalAlpha = Math.max(.25,t.confidence);
                            c.beginPath();c.arc(p.x,p.y,7,0,Math.PI*2);c.fill();c.globalAlpha=1;
                            if(t.heading !== null && t.heading !== undefined) {
                                const q = map.point([t.position[0]+Math.cos(t.heading),t.position[1]+Math.sin(t.heading)]);
                                c.beginPath();c.moveTo(p.x,p.y);c.lineTo(q.x,q.y);c.stroke();
                            }
                            label(t.id+" · "+Math.round(t.confidence*100)+"%",p);
                        }
                    }
                }
                OperatorText {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                    font.pixelSize: 12; color: Theme.muted; wrapMode: Text.Wrap
                    text: (root.isometric ? "等距平面投影，非真实3D高度。" : "28 × 15 m；原点左下。")
                        + " 红/蓝表示观测阵营；空心方框表示冲突。未知朝向不画方向线。"
                }
            }
            ScrollView {
                id: detailsScroll
                SplitView.preferredWidth: 360
                SplitView.minimumWidth: 300
                clip: true
                ColumnLayout {
                    width: detailsScroll.availableWidth
                    spacing: 12
                    OperatorText { Layout.fillWidth: true; text: "来源与时效"; font.pixelSize: 18 }
                    Repeater {
                        model: trackRows
                        delegate: Rectangle {
                            required property string rowJson
                            readonly property var modelData: JSON.parse(rowJson)
                            Layout.fillWidth: true
                            implicitHeight: contents.implicitHeight + 20
                            color: root.selectedId === modelData.id ? "#40564b" : Theme.hudSurface
                            border.color: modelData.conflict ? Theme.warning : Theme.line
                            ColumnLayout {
                                id: contents
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                OperatorText { Layout.fillWidth: true; text: modelData.id + " · " + (modelData.conflict ? "冲突，未合并" : "观测/融合估计"); wrapMode: Text.Wrap }
                                OperatorText {
                                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0
                                    color: Theme.muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                                    text: "置信度 " + Math.round(modelData.confidence*100) + "% · 剩余 " + modelData.remaining_ms + "ms\n"
                                        + modelData.evidence.map(e => e.kind + " · " + e.id + " · " + new Date(e.stamp_ms).toLocaleTimeString()).join("\n")
                                }
                                OperatorButton { text: "选择并播报给队内"; Layout.fillWidth: true; onClicked: { root.selectedId=modelData.id;root.host.announce(modelData.id, root.peerNode); } }
                            }
                        }
                    }
                    OperatorText { visible: root.displayedTracks.length === 0; text: "等待已授权、未过期的位置观测"; color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    OperatorButton {
                        Layout.fillWidth: true
                        text: (root.showObservations ? "收起" : "展开") + "本机与队友观测详情（视觉 " + (root.view.boxes ?? []).length
                            + " / 原始 " + (root.view.observations ?? []).length + "）"
                        onClicked: root.showObservations = !root.showObservations
                    }
                    Repeater {
                        model: root.showObservations ? root.view.boxes ?? [] : []
                        delegate: OperatorText {
                            required property var modelData
                            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0
                            wrapMode: Text.WrapAnywhere; color: Theme.muted; font.pixelSize: 12
                            text: "主视频 · " + modelData.team + " · " + modelData.label + " #" + modelData.track_id
                                + " · " + (modelData.occluded ? "陈旧/可能遮挡" : modelData.confirmed ? "多帧确认（估计）" : "候选")
                                + "\n" + new Date(modelData.stamp_ms).toLocaleTimeString() + " · " + modelData.age_ms + "ms · "
                                + Math.round(modelData.confidence*100) + "% · camera.main.normalized · bbox " + JSON.stringify(modelData.bbox)
                        }
                    }
                    Repeater {
                        model: root.showObservations ? root.view.observations ?? [] : []
                        delegate: OperatorText {
                            required property var modelData
                            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0
                            wrapMode: Text.WrapAnywhere; color: Theme.muted; font.pixelSize: 12
                            text: modelData.origin + "/" + modelData.source_id + "/" + modelData.target_id + " · " + modelData.kind
                                + "\n" + new Date(modelData.stamp_ms).toLocaleTimeString() + " · TTL " + modelData.ttl_ms + "ms · "
                                + Math.round(modelData.confidence*100) + "% · " + modelData.frame_id + "\n"
                                + (modelData.value !== undefined ? JSON.stringify(modelData.value) + " " + modelData.unit
                                    : modelData.position ? "位置 " + JSON.stringify(modelData.position) : "bbox " + JSON.stringify(modelData.bbox))
                                + (modelData.image_trail ? "\n图像轨迹（非地面坐标） " + JSON.stringify(modelData.image_trail) : "")
                        }
                    }
                    OperatorText { text: "模型与策略"; font.pixelSize: 18 }
                    OperatorText { Layout.fillWidth: true; text: root.view.model_status ?? "未启用模型"; wrapMode: Text.Wrap; color: Theme.muted }
                    TextField { id: question; Layout.fillWidth: true; placeholderText: "关注点（不会改变观测事实）"; Accessible.name: "战术关注点" }
                    OperatorText { Layout.fillWidth: true; wrapMode: Text.Wrap; text: root.view.advice?.text ?? "暂无有效建议" }
                    OperatorText { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 12; text: root.view.advice?.rationale ?? "模型建议属于推断，引用有效不等于内容一定正确。" }
                    OperatorText {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 12
                        text: root.view.advice?.text ? "时间 " + new Date(root.view.advice.stamp_ms).toLocaleTimeString()
                            + " · 置信度 " + Math.round(root.view.advice.confidence*100) + "%\n依据："
                            + (root.view.advice.evidence ?? []).join("，") : ""
                    }
                    OperatorButton { text: "播报当前建议"; enabled: !!root.view.advice?.text; Layout.fillWidth: true; onClicked: root.host.speakAdvice() }
                    OperatorText { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; text: (root.view.voice?.status ?? "语音未启用") + "\n在线来源：" + (root.view.team?.peers_online ?? []).join(", ") }
                    OperatorText { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 12; text: "网络接收 " + (root.view.team?.received ?? 0) + " · 拒绝 " + (root.view.team?.rejected ?? 0) + " · 发送错误 " + (root.view.team?.send_errors ?? 0) }
                    OperatorText { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 12; text: (root.view.vision?.status ?? "视觉未启用") + "\n模型、策略、共享和设备在配置文件中选择；缺失模块不影响主客户端。" }
                }
            }
        }
    }
}
