import QtQml

// 源码直接运行或没有匹配SDK工具时使用GLB；构建时可生成同名的资源目录描述。
QtObject {
    readonly property string qtVersion: ""
    readonly property url source: ""
    readonly property var files: []
}
