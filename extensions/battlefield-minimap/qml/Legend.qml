import QtQuick
import QtQuick.Controls
import "../../../qml/components" as Client

Client.OperatorText {
    id:root
    objectName:"minimapVisionLegend"
    property var snapshot:({markers:[],total:0,omitted:0,otherFrame:0,imageOnly:0})
    property int hiddenLabels:0
    property real hudScale:1
    text:"原图标：回传 · □视：估计 "+snapshot.markers.length+(snapshot.omitted?"/"+snapshot.total:"")
        +(snapshot.otherFrame?" · 异系 "+snapshot.otherFrame:"")+(snapshot.imageOnly?" · 未定位 "+snapshot.imageOnly:"")
    size:Math.max(10,9/Math.max(.1,hudScale));color:Client.Theme.warning;elide:Text.ElideRight
    Accessible.role:Accessible.StaticText
    Accessible.name:"原有机器人图标表示定位或雷达回传；空心方框及视字标签表示视觉估计，问号表示身份候选。"
        +"当前显示 "+snapshot.markers.length+"/"+snapshot.total+" 条视觉地面估计。未排下文字标签 "+hiddenLabels+" 条，空心锚点仍保留。"
        +"坐标系不同 "+snapshot.otherFrame+" 条、没有地面位置 "+snapshot.imageOnly+" 条，均未投影。"
        +"悬停空心框或标签可查看来源、时间、评分及误差；虚线圈为启发式误差范围，叉号表示来源冲突。"
    HoverHandler {id:hover;blocking:false}
    ToolTip.visible:hover.hovered
    ToolTip.delay:450
    ToolTip.text:Accessible.name
}
