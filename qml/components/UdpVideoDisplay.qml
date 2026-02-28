import QtQuick 6.2
// UDP视频接收展示模块
Item {
    id: root

    // ========== 视频显示区域 ==========
    Image {
        id: videoDisplay
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        z: 9
        smooth: true
        mipmap: true
        cache: false // 关键：禁用缓存，强制每次都刷新

        // 连接信号，收到新帧时刷新 source
        Connections {
            target: videoReceiver
            function onFrameReady() {
                // 这里的 "image://videoProvider/latest" 是关键
                // 加个随机数或者时间戳是为了强制 QML 重新请求图片
                videoDisplay.source = "image://videoProvider/latest?time=" + Date.now();
            }
        }
    }
}