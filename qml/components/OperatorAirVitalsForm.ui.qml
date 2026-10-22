import QtQuick

// 只接收显示值和动画分数。原始遥测、投影来源与时间核验留在行为层。
Item {
    id: root
    property bool ammoVisible: false
    property string ammoText: ""
    property bool ammoNumeric: false
    property color ammoColor: Theme.muted
    property string ammoCaption: ""
    property color ammoCaptionColor: Theme.muted
    property bool ammoRatioVisible: false
    property real ammoFraction: 0
    property real ammoFillOpacity: 0.25
    property bool progressVisible: false
    property bool progressRatioVisible: false
    property real progressFraction: 0
    property real progressFillOpacity: 0.25
    property string progressCaption: ""
    property color progressColor: Theme.muted
    property bool shooterVisible: false
    property string shooterText: ""
    property color shooterColor: Theme.muted
    property bool countVisible: false
    property string countCaption: ""
    property color countColor: Theme.muted
    property string fontFamily: Theme.fontFamily
    property string numberFontFamily: Theme.numberFamily
    property real ammoLeft: 0
    property real ammoTop: 0
    property real ammoWidth: 270
    property real ammoHeight: 26
    property real ammoSize: 22
    property real detailLeft: 288
    property real detailWidth: 156
    property real ammoCaptionTop: 0
    property real ammoCaptionHeight: 23
    property real ammoCaptionSize: 11
    property real bulletsLeft: 0
    property real bulletsTop: 32
    property real bulletsWidth: 270
    property real bulletsAspectRatio: 40 / 316
    property real bulletsBackgroundOpacity: 0.22
    property url bulletsBackgroundSource: "../resources/player/my_robot/airplane_statusbar_bullet_bg.png"
    property url bulletsFillSource: "../resources/player/my_robot/airplane_statusbar_bullet.png"
    property real progressLeft: 0
    property real progressTop: 74
    property real progressWidth: 270
    property real progressAspectRatio: 8 / 264
    property real progressSlantRatio: 4 / 264
    property color progressTint: Theme.blue
    property real progressBackgroundOpacity: 0.4
    property url progressBackgroundSource: "../resources/player/my_robot/airplane_statusbar_slid_bg.png"
    property url progressFillSource: root.progressBackgroundSource
    property url progressMaskSource: root.progressFillSource
    // 以标量暴露 ROI，供 Creator 属性面板直接编辑；保留原 rect 接口。
    property real progressBackgroundCropX: 10
    property real progressBackgroundCropY: 10
    property real progressBackgroundCropWidth: 264
    property real progressBackgroundCropHeight: 8
    property rect progressBackgroundClipRect: Qt.rect(root.progressBackgroundCropX,
                                                     root.progressBackgroundCropY,
                                                     root.progressBackgroundCropWidth,
                                                     root.progressBackgroundCropHeight)
    property real progressFillCropX: 10
    property real progressFillCropY: 10
    property real progressFillCropWidth: 264
    property real progressFillCropHeight: 8
    property rect progressFillClipRect: Qt.rect(root.progressFillCropX, root.progressFillCropY,
                                               root.progressFillCropWidth, root.progressFillCropHeight)
    property real progressMaskCropX: root.progressFillClipRect.x
    property real progressMaskCropY: root.progressFillClipRect.y
    property real progressMaskCropWidth: root.progressFillClipRect.width
    property real progressMaskCropHeight: root.progressFillClipRect.height
    property rect progressMaskClipRect: Qt.rect(root.progressMaskCropX, root.progressMaskCropY,
                                               root.progressMaskCropWidth, root.progressMaskCropHeight)
    property real shooterTop: 27
    property real shooterHeight: 23
    property real shooterSize: 11
    property real progressCaptionTop: 53
    property real progressCaptionHeight: 19
    property real progressCaptionSize: 10
    property real countTop: 76
    property real countHeight: 19
    property real countSize: 10
    property alias ammoControl: ammo
    property alias ammoCaptionControl: ammoCaptionLabel
    property alias bulletsControl: bullets
    property alias progressControl: counterTrack
    property alias progressFillControl: counterFill
    property alias shooterControl: shooter
    property alias progressCaptionControl: progressCaptionLabel
    property alias countControl: count
    width: 444
    height: 96

    OperatorText {
        id: ammo
        x: root.ammoLeft
        y: root.ammoTop
        width: root.ammoWidth
        height: root.ammoHeight
        visible: root.ammoVisible
        text: root.ammoText
        numeric: root.ammoNumeric
        font.family: root.ammoNumeric ? root.numberFontFamily : root.fontFamily
        font.bold: true
        size: root.ammoSize
        clip: true
        color: root.ammoColor
    }
    OperatorText {
        id: ammoCaptionLabel
        x: root.detailLeft
        y: root.ammoCaptionTop
        width: root.detailWidth
        height: root.ammoCaptionHeight
        visible: root.ammoVisible
        text: root.ammoCaption
        font.family: root.fontFamily
        size: root.ammoCaptionSize
        clip: true
        color: root.ammoCaptionColor
    }
    Item {
        id: bullets
        // 原前景／底衬同为316×40；宽度变化时保留原比例。
        x: root.bulletsLeft
        y: root.bulletsTop
        width: root.bulletsWidth
        height: width * root.bulletsAspectRatio
        visible: root.ammoVisible
        Image {
            anchors.fill: parent
            source: root.bulletsBackgroundSource
            fillMode: Image.Stretch
            mipmap: true
            opacity: root.bulletsBackgroundOpacity
            Accessible.ignored: true
        }
        Item {
            width: bullets.width * root.ammoFraction
            height: bullets.height
            clip: true
            visible: root.ammoRatioVisible && root.ammoFraction > 0
            opacity: root.ammoFillOpacity
            Image {
                width: bullets.width
                height: bullets.height
                source: root.bulletsFillSource
                fillMode: Image.Stretch
                mipmap: true
                Accessible.ignored: true
            }
        }
    }
    Item {
        id: counterTrack
        x: root.progressLeft
        y: root.progressTop
        width: root.progressWidth
        height: width * root.progressAspectRatio
        visible: root.progressVisible
        Image {
            anchors.fill: parent
            source: root.progressBackgroundSource
            sourceClipRect: root.progressBackgroundClipRect
            fillMode: Image.Stretch
            mipmap: true
            opacity: root.progressBackgroundOpacity
            Accessible.ignored: true
        }
        OperatorSlantedFill {
            id: counterFill
            anchors.fill: parent
            // 与原底衬共用实体ROI／alpha，不推测未知素材的语义。
            source: root.progressFillSource
            sourceClipRect: root.progressFillClipRect
            maskSource: root.progressMaskSource
            maskClipRect: root.progressMaskClipRect
            fraction: root.progressFraction
            slantWidth: width * root.progressSlantRatio
            tint: root.progressTint
            visible: root.progressRatioVisible && root.progressFraction > 0
            opacity: root.progressFillOpacity
        }
    }
    OperatorText {
        id: shooter
        x: root.detailLeft
        y: root.shooterTop
        width: root.detailWidth
        height: root.shooterHeight
        visible: root.shooterVisible
        text: root.shooterText
        font.family: root.fontFamily
        size: root.shooterSize
        clip: true
        color: root.shooterColor
    }
    OperatorText {
        id: progressCaptionLabel
        x: root.detailLeft
        y: root.progressCaptionTop
        width: root.detailWidth
        height: root.progressCaptionHeight
        visible: root.progressVisible
        text: root.progressCaption
        font.family: root.fontFamily
        size: root.progressCaptionSize
        clip: true
        color: root.progressColor
    }
    OperatorText {
        id: count
        x: root.detailLeft
        y: root.countTop
        width: root.detailWidth
        height: root.countHeight
        visible: root.countVisible
        text: root.countCaption
        font.family: root.fontFamily
        size: root.countSize
        clip: true
        color: root.countColor
    }
}
