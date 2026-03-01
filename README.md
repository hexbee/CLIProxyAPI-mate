# CLIProxyAPI-mate

自动化工具更新脚本集合。

## 快速开始

```bash
# CLIProxyAPIPlus (跨平台)
bash update_cliproxyapiplus.sh

# CLIProxyAPI (Windows)
python update_cli_proxy.py

# Claude Code
bash update_claude_code.sh

# OpenAI Codex
bash update_openai_codex.sh
```

## CLIProxyAPIPlus

跨平台更新脚本 (Windows/Linux)，自动检测版本、备份配置、智能更新。

### 常用命令

| 命令 | 说明 |
|------|------|
| `bash update_cliproxyapiplus.sh` | 更新到最新版本 |
| `bash update_cliproxyapiplus.sh --check-only` | 仅检查版本信息，不做更改 |
| `bash update_cliproxyapiplus.sh --dry-run` | 模拟运行，显示计划操作 |
| `bash update_cliproxyapiplus.sh --force` | 强制重新安装当前版本 |
| `bash update_cliproxyapiplus.sh --target-version v6.8.34-0` | 安装指定版本 |
| `bash update_cliproxyapiplus.sh --allow-downgrade` | 允许降级到旧版本 |
| `bash update_cliproxyapiplus.sh --yes` | 自动确认所有提示 |
| `bash update_cliproxyapiplus.sh --keep-temp` | 保留临时文件用于调试 |
| `bash update_cliproxyapiplus.sh --help` | 显示帮助信息 |

### 常用组合

| 命令 | 使用场景 |
|------|---------|
| `bash update_cliproxyapiplus.sh --force --target-version v6.8.34-0` | 强制安装特定版本 |
| `bash update_cliproxyapiplus.sh --allow-downgrade --target-version v6.8.34-0` | 降级到指定版本 |
| `bash update_cliproxyapiplus.sh --dry-run --target-version v6.8.34-0` | 预览安装特定版本的操作 |
| `bash update_cliproxyapiplus.sh --yes --allow-downgrade --target-version v6.8.34-0` | 自动降级到指定版本 |

## CLIProxyAPI

Windows 专用 Python 更新脚本。

```bash
python update_cli_proxy.py  # 自动下载最新版、备份配置、解压安装
```

## Claude Code

检查并更新 Claude Code。

```bash
bash update_claude_code.sh  # 对比 CHANGELOG.md，有新版则执行 claude install
```

## OpenAI Codex

检查并更新全局 `@openai/codex`。

```bash
bash update_openai_codex.sh  # 查询 npm registry，落后则执行 npm i -g
```
