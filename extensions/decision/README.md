# 决策建议服务插件 (extensions/decision)

## 插件概述与角色定位
本目录提供只读战术建议模型接入服务，包括基于进程调用的 Codex CLI 插件和基于 HTTP 协议的通用大模型建议插件。

- **插件 ID**：
  - `decision.codex`：调用本机已安装的 Codex 命令行工具获取建议。
  - `decision.http`：支持 OpenAI Responses API 规范或兼容格式（如 DeepSeek Chat / 本地推理服务）。
- **接口契约**：实现 `ExtensionPlugin`，角色定义为 `decision`。
- **独立性说明**：为客户端提供可选决策支持的原生插件库。所有建议结果**仅限只读展示，严禁直接生成任何比赛控制指令或操控机器底盘/云台**。

## 依赖与启用条件
- **Codex 模式**：
  - 依赖本机已预先安装的 `codex` 可执行文件。
  - 必须通过 `auth_home` 明确指定已登录鉴权的独立工作目录。客户端不负责自动登录或复制凭据，严禁透传未知参数。
- **HTTP 模式**：
  - 依赖能够访问的目标 HTTP/HTTPS 模型推理端点。
  - 本机端点（`local-http`）仅限 loopback（`127.0.0.1` / `localhost`）；外部端点必须为 `https`。
  - 密钥通过环境变量名引用，严禁在配置文件中写入真实密钥。

## 启动入口与切换规范
- **UI 入口**：`Ctrl+Shift+E` / 插件管理，选中决策行进行配置与显式启用。
- **CLI 参数**：
  - `--decision` / `--no-decision`：显式开启/禁用决策服务。
  - `--decision-plugin=decision.http`（或 `decision.codex`）。
  - `--decision-api=responses`（或 `chat`）。
  - `--decision-endpoint=https://api.openai.com/v1/responses`。
  - `--decision-model=model-id`。
  - `--decision-key-env=OPENAI_API_KEY`。
  - `--decision-timeout-ms=15000`。
  - `--decision-temperature=0.2`（可选，0.0~2.0）。
- **切换提示**：若更换模型提供者类型（例如从 HTTP 切换至 Codex），必须主动清理先前旧的 HTTP 端点及密钥配置，避免遗留字段校验报错。

## 配置字段与约束

### 1. Codex 插件 (`decision.codex`)
| 字段名 | 类型 | 默认值 | 约束说明 |
| :--- | :--- | :--- | :--- |
| `executable` | string | `"codex"` | Codex 程序路径，长度 ≤ 1024 |
| `auth_home` | string | `""` | 引用已完成认证的专用目录路径 |
| `model` | string | 必填 | 模型标识，长度 ≤ 128 |
| `reasoning` | string | `"high"` | 推理强度：`low` / `medium` / `high` |
| `timeout_ms` | integer | `15000` | 超时时间 (50–120000 ms) |
| `max_output_tokens`| integer | `1200` | 长度提示 (256–8192)，Codex CLI 不提供此处的硬令牌限制 |

> 拒绝任何附加命令参数或未知配置键。

### 2. HTTP 决策插件 (`decision.http`)
| 字段名 | 类型 | 默认值 | 约束说明 |
| :--- | :--- | :--- | :--- |
| `provider` | string | `"generic"` | HTTP 插件的提供者标识；`deepseek` 才可启用其专属 thinking。模型提供者页面另有自己的 kind，不是 HTTP 插件的 provider 字段 |
| `endpoint` | string | 必填 | 完整安全 URL。本机限 loopback，外部限 https；禁止带 query 或 token |
| `api` | string | `"responses"` | 接口类型：`responses` 或 `chat` |
| `format` | string | `"json-schema"`| 格式：`json-schema` 或 `json-object` |
| `model` | string | 必填 | 模型 ID，长度 ≤ 128 |
| `key_env` | string | `""` | 密钥环境变量名，正则 `^[A-Za-z_][A-Za-z0-9_]{0,95}$` |
| `timeout_ms` | integer | `15000` | 超时时间 (50–120000 ms) |
| `max_output_tokens`| integer | `1200` | 输出预算 (256–8192) |
| `thinking` | boolean | `false` | 深度思考开关（仅 DeepSeek Chat 预设支持） |

### 最小配置示例 (Profile 片段)
```json
{
  "schema": 1,
  "options": {
    "decision": true,
    "decision-plugin": "decision.http",
    "decision-api": "chat",
    "decision-endpoint": "http://127.0.0.1:11434/v1/chat/completions",
    "decision-model": "qwen2.5:7b",
    "decision-timeout-ms": 10000
  },
  "plugins": {
    "decision": {
      "endpoint": "http://127.0.0.1:11434/v1/chat/completions",
      "api": "chat",
      "format": "json-object",
      "model": "qwen2.5:7b",
      "timeout_ms": 10000,
      "max_output_tokens": 1024,
      "provider": "generic"
    }
  }
}
```

## 使用流程与状态验证
1. 在插件管理或 Profile 中正确配置，并设置相关环境变量。
2. 点击启用后，服务进入就绪态。当有请求触发时，插件发起异步调用。
3. **成功标志**：界面决策看板（HUD）展示结构化战术建议信息。
4. **异常处理**：若后端无响应或超时，插件自动放弃当前请求并重置状态，不会导致界面冻结；核心 UDP/MQTT 可以继续运行，进程仍共享 CPU 与内存资源。

## 限制说明
- 严禁编造未经支持的参数，严格限定白名单字段。
- 文档与协议详见 [TECHNICAL.md](../../docs/TECHNICAL.md)。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。

## 态势运行时的独立归属

本目录还承载态势模型的 Python 实现 `runtime/advice_model.py`，旧 `battlefield/runtime/model.py` 保留兼容导入。协调器通过可选适配器懒加载，未启用时不创建执行器；文件缺失或普通异常局部停用。该调度仍在协调器进程中，与原生 `decision.http`／`decision.codex` 服务并非同一套调用入口，不宣称所有模型调用已独立进程隔离。完整边界见[插件隔离与验收](../../docs/TECHNICAL.md#plugin-isolation)。
