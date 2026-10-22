import QtQuick

Image {
    property string asset: ""
    source: asset.length ? "../resources/engine-137/sprites/" + asset
                          + (asset.endsWith(".png") ? "" : ".png") : ""
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
}
