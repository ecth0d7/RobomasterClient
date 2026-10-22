# 英雄吊射运动拖影与轨迹候选 (extensions/hero-projectile)

## 模块定位与现实边界
本模块用于在英雄机器人第一视角视频流中提取吊射运动像素拖影与运动候选。清单目录 ID 为 `hero-projectile`，插件管理页模块 ID 为 `vision.hero.projectile`。

> [!IMPORTANT]
> **技术现状声明：当前未完成稳定真实弹丸轨迹识别。**
> 上游编码端（参考 [video_encoder_node.cpp](https://github.com/wele0612/Pacific_doorlock_sniper/blob/main/src/doorlock_sniper/src/video_encoder_node.cpp)）仅在视频编码前保留运动像素，这绝不代表客户端解码后即可自然获得真实物理弹道。客户端画面中的青色像素仅来自观测位置的时域差分对比，不能称为“弹丸确认”；已有亮点关联线也不等于新暗点的身份识别，模块更不具备物理弹道求解能力。

## 计算原理与过滤机制
接收端保留明暗运动像素拖影，亮点候选仍单独关联，去除了早期单纯依赖 `gray > 170` 的绝对高亮限制：
- **差分触发**：灰度差阈值 `> 18`，相邻帧差阈值 `> 12`。
- **色彩模式**：`color` 字段（可选 `"bright"`、`"green"`、`"red"`）仅影响高亮候选分支的筛选倾向，不影响明暗像素拖影。
- **时空收敛**：对局部连通区域进行面积限幅；像素拖影最多保留 8 帧或 450 ms；亮点关联最多保留 12 个采样点。
- **异常重置**：检测到单帧大范围运动（检测区域内运动像素占比达到 30%）、帧间隔超限或视频流重置时，立即清空历史观测缓存。

## 运行环境与宿主依赖
- **运行环境**：需自备 Python 运行环境并安装 `numpy` 与 `opencv-python`。本模块不依赖深度学习推理模型，由 `battlefield` 协调器管理，运行在独立 `runtime/worker.py` 图像进程。
- **输入依赖**：英雄部署模式下接收 H264 视频流解码帧后才有有效输入（比赛状态允许下，长按 `K` 部署，长按 `L` 退出部署）。
- **启停隔离**：模块默认关闭且不改自动启动。仅修改视觉／吊射参数或共享开关时可独立停启对应工作进程，保留协调器、队内会话和 YOLO；其它公共配置变化仍重启协调器。工作进程故障或 3 秒超时只停该任务，显式停启重试。旧观测依原 TTL 到期，不影响主程序 MQTT/UDP 与 QML。

## 部署与配置说明
在插件管理面板（`Ctrl+Shift+E`）中，**必须填入完整的态势 JSON 绝对路径**，再点击对应行启用。态势配置文件以 [extensions/battlefield/config/default.json](../battlefield/config/default.json) 为模板，严禁将仅包含 `projectile` 节点的配置片段直接填入插件管理面板。

### 1. 准备态势配置
```bash
cp extensions/battlefield/config/default.json /tmp/robot-vision.json
```
在 `/tmp/robot-vision.json` 中，将 `python` 字段修改为已安装 Python 环境的绝对路径，并编辑其中的 `projectile` 字段。

### 2. projectile 字段参数（替换完整配置中的 projectile 节点）
```json
{
  "projectile": {
    "enabled": true,
    "color": "bright",
    "roi": [0.04, 0.04, 0.92, 0.92],
    "exclude_regions": [],
    "share": false
  }
}
```

| 参数 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `enabled` | boolean | `false` | 显式启用/关闭运动拖影计算 |
| `color` | string | `"bright"` | 亮点候选倾向：`"bright"`、`"green"`、`"red"` |
| `roi` | array | `[0.04, 0.04, 0.92, 0.92]` | 归一化检测区域 `[x, y, w, h]`，取值 `0.0~1.0` |
| `exclude_regions` | array | `[]` | 归一化排除矩形 `[x, y, w, h]`，最多支持 16 个 |
| `share` | boolean | `false` | 组网数据共享开关 |

## 队友共享与网络边界
当且仅当 `projectile.share = true` 且客户端处于已授权的 `team` 组网环境时，模块仅向队友同步已关联候选的 `image_trail` 屏幕归一化坐标。严禁将该数据当作地面真实位置，系统也不会传输任何 PNG 抓图或原始图像切片。

## 运行验证与常见问题

### 成功运行判断
1. 伴生进程正常拉起，日志显示成功接收英雄解码帧并有差分拖影数据输出。
2. 退出部署模式时观测图层自动清空。
3. 停用模块时，点击模块行的“停用服务”即可重载态势进程，无需重启客户端主程序。

### 常见问题与现实局限
- **误检问题**：若原始视频中自带准星预测圈、云台剧烈晃动或光影突变，差分算法极易将准星圆弧与边缘反光误检为运动候选。
- **验收现状**：接入核对中测试了 208 解码帧且 0 解码错、退出清空逻辑通过，但这仅证明数据链路畅通，绝不是弹丸识别率的证明。真实复杂赛场下的弹丸轨迹尚未完成算法验收。

## 打包分发规范
本说明文件随源码一同分发。制作 `.rmplugin` 扩展包时，必须在 插件包构建声明的 `FILES` 列表中明确列出 `README.md`。包清单（manifest）中不要添加未知的文档字段；缺少说明文件的旧版扩展包仍保持向后兼容加载能力。协议细节请查阅 [TECHNICAL.md](../../docs/TECHNICAL.md)。

进程隔离、共享兼容及验收边界见[技术手册](../../docs/TECHNICAL.md#plugin-isolation)。本轮资源采样中吊射进程等待输入，不能当作双视频同时推理的峰值。
