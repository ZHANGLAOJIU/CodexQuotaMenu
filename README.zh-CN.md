# Codex Quota Menu 中文说明

一个轻量、原生的 macOS 菜单栏工具，实时显示 Codex 的 **5 小时剩余额度**与**一周剩余额度**。

```text
⚡ 5h71% W95%
```

菜单栏里的数字表示“剩余百分比”。点击后可以查看已用百分比、两个窗口的准确刷新时间、最近同步时间以及当前数据来源。

[English README](README.md)

## 主要特点

- 每 30 秒与 Codex 官方用量接口同步。
- 同时显示 5 小时和一周两个额度窗口。
- 点击菜单栏即可查看准确刷新时间。
- 官方接口异常时自动读取本地 Codex 响应日志作为备用。
- 明确标记“官方接口”或“本地日志”，不会把旧数据伪装成实时数据。
- 原生 Swift + AppKit，不依赖 Electron、Homebrew 或第三方运行时。
- 安装在当前用户目录，不需要 `sudo`。
- 登录 macOS 后自动启动。
- 不收集统计信息，不保存账号凭据，也不接入任何第三方服务。

## 安装要求

- macOS 13 Ventura 或更高版本。
- 已安装并登录 Codex 桌面端或 Codex CLI。
- 已安装 Xcode Command Line Tools。

如果没有命令行工具，先运行：

```bash
xcode-select --install
```

## 一键安装

```bash
git clone https://github.com/ZHANGLAOJIU/CodexQuotaMenu.git
cd CodexQuotaMenu
./scripts/install.sh
```

脚本会在本机编译应用、安装到 `~/Applications/CodexQuotaMenu.app`、创建用户级开机启动项并立即打开。整个过程不需要管理员权限。

## 更新

```bash
cd CodexQuotaMenu
git pull
./scripts/install.sh
```

## 卸载

```bash
./scripts/uninstall.sh
```

## 数据与隐私

应用会从 `~/.codex/auth.json` 读取 Codex 已有的访问令牌和账号 ID，并仅向下面这个官方地址查询用量：

```text
https://chatgpt.com/backend-api/wham/usage
```

令牌只在内存中参与请求，不会被本程序写入文件或日志。程序没有分析统计、遥测、广告、自动更新服务或第三方 SDK。

当网络请求失败时，程序会尝试读取以下本地数据库里最新的 `x-codex-*` 响应头：

- `~/.codex/logs_2.sqlite`
- `~/.codex/sqlite/logs_2.sqlite`

点击菜单栏后会显示当前数据来源。如果使用的是本地备用数据，也会给出提示。

## 常见问题

### 菜单栏没有出现

先检查程序是否运行：

```bash
launchctl print gui/$(id -u)/io.github.zhanglaojiu.codexquotamenu | grep -E 'state =|pid ='
```

如果顶部图标太多，macOS 或第三方菜单栏管理器可能会暂时隐藏它。

### 显示 `--`

打开 Codex，确认账号仍处于登录状态，然后点击菜单里的“立即同步”。官方接口与本地备用数据都不可用时，程序会选择显示未知值，而不是继续展示无法确认的新鲜度的数据。

### 查看日志

```bash
tail -f ~/Library/Logs/CodexQuotaMenu.debug.log
tail -f ~/Library/Logs/CodexQuotaMenu.err.log
```

日志会记录数据来源和用量百分比，但不会记录令牌。

## 说明

这是独立的社区项目，与 OpenAI 没有隶属或背书关系。Codex、ChatGPT 和 OpenAI 是 OpenAI 的商标。Codex 内部接口在未来版本中可能继续变化，欢迎提交 issue 或 pull request 一起维护兼容性。

如果它确实让你少打开了几次用量页面，欢迎点一个 Star，让更多 Codex 用户能找到它。
