import QtQuick

Row {
    spacing: 12
    // 使用内容的自然高度对齐边框，不让兄弟组件互相绑定 height。
    property real maximumHeight: {
        let maximum = 0;
        for (const child of children)
            maximum = Math.max(maximum, child.implicitHeight);
        return maximum;
    }
}
