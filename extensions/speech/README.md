# 本地语音合成与回放插件 (extensions/speech)

## 插件清单与架构定位
本目录包含两个底层语音合成插件，实现原生 `ExtensionPlugin` 接口，角色定义为 `speech`：
- `speech.espeak`：基于本地外部命令行工具的异步受限语音合成插件（依赖 `espeak-ng` 及可选 `aplay`）。
- `speech.piper-http`：基于本地 HTTP 服务的语音合成插件，通过 POST JSON 请求将文本转为语音并统一调度。

本目录代码属于客户端插件库与服务适配实现，编译为动态库随宿主加载。语音服务本身为可选服务，受准备阶段阶段锁显式启停保护；仅启用对象并不代表底层进程或外部服务可用。

## 依赖与启用条件
1. **命令行/系统依赖**：
   - `speech.espeak` 需要系统中安装有 `espeak-ng` 二进制可执行程序（仅安装库文件不足以运行）；若需系统音频设备自动回放，还需依赖 `aplay`。若程序缺失，应先安装或配置已有程序的绝对路径。
   - `speech.piper-http` 要求本地运行有兼容的 Piper HTTP 服务，接收包含 `{text, voice?}` 的 POST JSON 请求并返回标准 WAV 音频流。客户端请求 endpoint 受到回环地址（loopback: 127.0.0.1）限制，启用仅创建内部 HTTP 请求对象。
2. **启用入口**：
   - 界面操作：使用快捷键 `Ctrl+Shift+E` 打开「插件管理」界面，在准备阶段允许编辑时选择并显式启停语音服务。
   - 命令行与配置文件：可在启动参数追加 `--speech` 启用语音服务；追加 `--speech-play` 开启音频设备回放。

## 配置字段说明
配置支持通过启动 Profile JSON 中的 `plugins.speech` 节点传递，各键值具有严格约束：

| 字段名 | 类型 | 默认值 | 约束说明 |
| :--- | :--- | :--- | :--- |
| `executable` | 字符串 | 空（PATH 查找） | `espeak-ng` 可执行文件完整路径（限 `speech.espeak`） |
| `voice` | 字符串 | `"cmn"` | 语音语言标识代码（如普通话 `cmn`） |
| `speed` | 整数 | `175` | 语速数值，范围 80–350 |
| `endpoint` | 字符串 | `"http://127.0.0.1:5002/synthesize"` | Piper HTTP 接口完整 URL，必须为本地 loopback HTTP 地址，不含账号、查询串或片段 |
| `model` | 字符串 | 空（服务默认） | 可选 Piper 服务端音色标识，最长128字符（限 `speech.piper-http`） |
| `playback` | 布尔 | `false` | 是否直接通过本地音频设备进行回放 |
| `player` | 字符串 | 空（PATH 查找） | 音频播放器可执行文件路径，默认尝试在 PATH 中查找 `aplay` |
| `timeout_ms` | 整数 | `15000` | 单次合成或执行超时时间，单位毫秒，范围 50–60000 |

命令行也支持 `--speech-plugin`、`--speech-executable`、`--speech-player`、`--speech-voice`、`--speech-endpoint`、`--speech-model`；参数应与所选引擎匹配。

## 最小配置与使用示例
在启动配置文件（如 `profile.json`）中声明最小可用配置：

```json
{
  "schema": 1,
  "options": {
    "speech": true,
    "speech-plugin": "speech.piper-http"
  },
  "plugins": {
    "speech": {
      "endpoint": "http://127.0.0.1:5002/synthesize",
      "playback": false,
      "timeout_ms": 15000
    }
  }
}
```

**使用与状态判断**：
通过 `Ctrl+Shift+E` 插件管理窗口启动语音服务后，检查服务状态是否转为运行。点击「打开语音面板」，输入短文本并提交合成，检查返回的音频格式、时长及错误反馈。由于默认 `playback` 为 `false`，仅生成语音数据不会直接占用声卡播放；若开启 `playback: true`，需验证外部回放进程未被阻塞。

## 停用、缺失与异常处理
- **程序缺失**：若缺少 `espeak-ng` 或找不到指定播放器，配置校验将报错并终止合成任务，控制台提示找不到有效可执行文件。
- **HTTP 断连**：Piper HTTP 服务未启动或端点非回环地址时，请求返回网络错误或超时（超出 `timeout_ms`）；失败任务不自动重试，语音队列将丢弃当前条目并记录警告，不会阻塞主事件循环与遥测链路。
- **停用操作**：在插件管理点击停用，或启动时传入 `--no-speech`，内部队列即刻清空未处理语音文本，释放进程句柄。

关于系统架构设计与通用插件总线协议，请参考 [TECHNICAL.md](../../docs/TECHNICAL.md)。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。

## 态势运行时的独立归属

本目录还承载态势语音队列 `runtime/voice_queue.py` 及 `runtime/speech_render.py`，旧模块名保留兼容入口。未启用时不创建队列执行器，缺失或普通异常使该服务停用。队列调度仍与协调器同进程，实际合成／播放沿用现有适配；原生插件入口继续兼容。实际 TTS 验证生成 WAV 并覆盖不可用设备处理，未声称现场扬声器或实时队内麦克风对讲已验收。完整边界见[插件隔离与验收](../../docs/TECHNICAL.md#plugin-isolation)。
