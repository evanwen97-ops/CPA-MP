# CPA 本地启动器

这个仓库用于在 Windows 上一键启动本地 CPA 服务组合：

- [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)：本地 AI Gateway，提供 OpenAI/Gemini/Claude/Codex/Grok 兼容接口。
- [CPA Manager Plus](https://github.com/seakee/CPA-Manager-Plus)：CLIProxyAPI 的本地监控与管理面板。
- `StartCPA.ps1` / `StartCPA.exe`：本仓库的托盘启动器，后台启动两个服务并打开管理页面。

## 项目结构

```text
.
├── StartCPA.ps1          # PowerShell 托盘启动脚本
├── StartCPA.exe          # 由启动脚本打包出的 Windows 可执行文件
├── SetupCPA.ps1          # 首次初始化脚本：从 GitHub Releases 下载两个组件并生成基础配置
├── cpa.ico               # 托盘图标
├── .gitignore            # 忽略下载的发行包、本地配置、数据和密钥
├── CLIProxyAPI_*/        # 本地已配置的 CLIProxyAPI 目录，不上传
└── cpa-manager-plus_*/   # 本地已配置的 CPA Manager Plus 目录，不上传
```

## 为什么不上传两个组件目录

`CLIProxyAPI_*_windows_amd64/` 和 `cpa-manager-plus_*_windows_amd64/` 是上游项目的二进制发行包，里面还可能包含本地配置、密钥、认证文件和 SQLite 数据。仓库通过 `.gitignore` 排除了这些目录，只保留启动器和初始化脚本。

## 首次使用

克隆仓库后，在 PowerShell 中运行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\SetupCPA.ps1
.\StartCPA.ps1
```

`SetupCPA.ps1` 会做这些事：

1. 从 GitHub Releases 下载最新 Windows amd64 版本的 CLIProxyAPI。
2. 从 GitHub Releases 下载最新 Windows amd64 版本的 CPA Manager Plus。
3. 解压到：
   - `CLIProxyAPI_windows_amd64/`
   - `cpa-manager-plus_windows_amd64/`
4. 生成基础配置：
   - `CLIProxyAPI_windows_amd64/config.yaml`
   - `cpa-manager-plus_windows_amd64/config.json`
5. 将随机生成的 API Key 和 Management Key 写入 `LOCAL_CONFIG.generated.txt`。

> `LOCAL_CONFIG.generated.txt` 已被 `.gitignore` 忽略，请不要提交到 GitHub。

## 指定版本或强制重装

默认下载最新版本。也可以指定 tag：

```powershell
.\SetupCPA.ps1 -CliProxyVersion "v7.2.50" -CpaManagerPlusVersion "v1.10.2"
```

如需覆盖已有下载目录和配置：

```powershell
.\SetupCPA.ps1 -Force
```

## 启动方式

```powershell
.\StartCPA.ps1
```

启动后会：

1. 在项目子目录中递归查找 `cli-proxy-api.exe` 并后台启动。
2. 在项目子目录中递归查找 `cpa-manager-plus.exe` 并后台启动。
3. 打开 `http://localhost:18317`。
4. 在系统托盘显示 CPA 图标，可右键打开主页或退出服务。

如果使用 `StartCPA.exe`，效果与 `StartCPA.ps1` 相同。

## 默认端口

| 服务 | 默认地址 |
|---|---|
| CLIProxyAPI | `http://127.0.0.1:8317` |
| CPA Manager Plus | `http://127.0.0.1:18317` |

## 上传到 GitHub 前检查

建议上传前确认只包含启动器和脚本：

```powershell
git status
```

不要提交以下内容：

- `CLIProxyAPI_*_windows_amd64/`
- `CLIProxyAPI_windows_amd64/`
- `cpa-manager-plus_*_windows_amd64/`
- `cpa-manager-plus_windows_amd64/`
- `.downloads/`
- `LOCAL_CONFIG.generated.txt`
- 任何包含 API Key、Management Key、OAuth token、SQLite 数据的文件

## 后续配置

初始化脚本只生成可运行的最小配置。启动后请在 CPA Manager Plus 页面中继续配置：

1. 填写 CLIProxyAPI 地址：`http://127.0.0.1:8317`。
2. 填写 `LOCAL_CONFIG.generated.txt` 中的 CLIProxyAPI Management Key。
3. 按需要导入 Claude Code、Codex、Gemini 等账号或 API Key。
4. 确认请求监控和用量统计配置。
