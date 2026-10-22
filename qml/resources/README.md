# 界面运行资源与许可

Runtime UI assets, catalogs, fonts and license notices are preserved. Documentation cleanup does not remove application resources.

QML运行所需贴图、位图／矢量图标、图集、场地图片、字体、资源目录及清单均保留。组件使用项目相对路径，不读取开发者Downloads或临时目录。部署时复制完整qml包，保持components与resources的相对关系。

文档插图、操作教程及视觉过程报告的清理不改变运行素材，也不因源码采用某许可就替第三方内容授予相同许可。

| 保留范围 | 用途 |
| --- | --- |
| player及official资源 | 选手端参考素材；来源与版本按各自许可／清单区分 |
| engine-137资源与catalog | 已整合的引擎素材及来源目录；不是全部同时显示的承诺 |
| 字体及许可证 | 项目内FontLoader相对路径，避免依赖另一台电脑的系统字体安装 |
| 各资源catalog／manifest／selected-assets | 来源、分类及组件选图信息；不将静态资源误当实时数据 |

法律与来源说明：

- [上游素材授权记录](player/SOURCE-ASSET_LICENSES.md)及相邻SOURCE-LICENSE保留原有第三方权利范围。
- [字体说明](fonts/README.md)及相邻LICENSE文本继续适用。
- [原创图标归属](player/icons/README.md)保留项目创作来源。

运行资源存在不证明数据来源、规则映射、界面或迁移已验收。构建与分发见唯一维护的[技术文档](../../docs/TECHNICAL.md#startup)。本目录及字体／原创图标旁的说明用于素材来源、归属和许可保留。
