# CLIProxyAPI-mate

自动化工具更新脚本集合。

## 快速开始

```bash
# CLIProxyAPIPlus
bash update_cliproxyapiplus.sh

# CLIProxyAPI
bash update_cliproxyapi.sh

# Claude Code
bash update_claude_code.sh

# OpenAI Codex
bash update_openai_codex.sh
```

## CLIProxyAPIPlus

跨平台更新脚本（Windows/Linux），自动检测版本、备份配置、智能更新。

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

跨平台 Bash 更新脚本（Windows/Linux/macOS），自动检测版本、备份配置、下载解压并校验安装结果。

### 常用命令

| 命令 | 说明 |
|------|------|
| `bash update_cliproxyapi.sh` | 更新到最新版本 |
| `bash update_cliproxyapi.sh --check-only` | 仅检查本地与目标版本 |
| `bash update_cliproxyapi.sh --dry-run` | 模拟运行，显示计划操作 |
| `bash update_cliproxyapi.sh --force` | 强制重新安装当前版本 |
| `bash update_cliproxyapi.sh --target-version v6.8.35` | 安装指定版本 |
| `bash update_cliproxyapi.sh --allow-downgrade` | 允许降级到旧版本 |
| `bash update_cliproxyapi.sh --keep-temp` | 保留临时文件用于调试 |
| `bash update_cliproxyapi.sh --help` | 显示帮助信息 |

## Claude Code

检查并更新 Claude Code。

```bash
bash update_claude_code.sh
```

## OpenAI Codex

检查并更新全局 `@openai/codex`。

```bash
bash update_openai_codex.sh
```
