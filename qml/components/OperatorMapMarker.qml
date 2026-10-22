import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorMapData.js" as MapData
import "OperatorMapLabelLayout.js" as Layout

Item {
    id:root
    property int mode:1
    property string letter:"C"
    property bool draft:false
    property bool stale:false
    property bool compact:false
    property string coordinateText:""
    property var obstacles:[]
    readonly property color markerColor:mode===3 ? "#ffb13c" : "#11e69a"
    readonly property real hudScale:Window.window?.ui?.layoutScale??1
    readonly property real captionSize:Math.max(12,9/Math.max(.1,hudScale))
    readonly property var labelRect:{
        if(compact || !coordinateText || !parent)return null;
        const w=180,h=Math.ceil(Math.max(captionSize,9.5/Math.max(.1,hudScale))*1.6+2),candidates=[];
        for(const gap of [8,18,30]) {
            candidates.push({x:x+(width-w)/2,y:y+height+gap,w:w,h:h});
            candidates.push({x:x+(width-w)/2,y:y-h-gap,w:w,h:h});
        }
        for(const candidate of candidates) {
            candidate.x=Math.max(2,Math.min(parent.width-w-2,candidate.x));
            if(candidate.y>=2 && candidate.y+h<=parent.height-2
                && !obstacles.some(o=>Layout.overlaps(candidate,o,2)))return candidate;
        }
        return null;
    }
    width:compact?22:38
    height:width
    visible:mode>=1 && mode<=4 && (mode!==4 || MapData.letters.includes(letter))
    opacity:stale ? .45 : 1
    Image {
        anchors.fill:parent
        source:root.mode>=1 && root.mode<=3 ? "../resources/icons/map/"+["attack","defend","warning"][root.mode-1]+(root.draft || root.stale ? "-outline" : "")+".svg" : ""
        sourceSize.width:64;sourceSize.height:64;fillMode:Image.PreserveAspectFit
    }
    OperatorText {
        anchors.fill:parent;visible:root.mode===4
        text:root.letter;color:root.markerColor;size:root.compact?18:Math.min(30,root.height*.72)
        horizontalAlignment:Text.AlignHCenter;numeric:true
    }
    OperatorText {
        objectName:"mapMarkerCoordinates"
        x:(root.labelRect?.x??0)-root.x;y:(root.labelRect?.y??0)-root.y
        width:root.labelRect?.w??0;height:root.labelRect?.h??0
        visible:root.labelRect!==null
        text:(root.stale ? "旧 " : "")+root.coordinateText;color:root.markerColor;size:root.captionSize
        horizontalAlignment:Text.AlignHCenter;numeric:true
    }
    Accessible.role:Accessible.StaticText
    Accessible.name:MapData.markerName(mode,mode===4 ? letter.charCodeAt(0) : 0)+(coordinateText ? " · "+coordinateText : "")+(stale?" · 旧数据":"")
}
