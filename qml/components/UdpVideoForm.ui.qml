import QtQuick 6.2

Item {
    implicitWidth: 1280
    implicitHeight: 720
    width: implicitWidth
    height: implicitHeight
    property alias videoDisplay: videoDisplay

    Rectangle { anchors.fill: parent; color: Theme.videoBackground }
    Image {
        id: videoDisplay
        objectName: "operatorVideoImage"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        z: 9
        smooth: true
        mipmap: false
        cache: false
    }
}
