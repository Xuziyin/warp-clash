# AGENTS.md — warp

## 项目概况

包含 `wgcf.exe`（WireGuard 协议）和 `usque.exe`（MASQUE 协议）。  
目标是**利用 Cloudflare Warp 工具生成配置文件，转换输出为 Clash 临时订阅链接/内容**。  

> 当前脚本已简化为仅 MASQUE 协议。

## 核心命令工作流

```powershell
# 1. 注册新 Warp 设备，生成 wgcf-account.toml
.\wgcf.exe register

# 2. 生成 WireGuard 配置文件（输出 wgcf-profile.conf）
.\wgcf.exe generate

# 3. 查看账户状态
.\wgcf.exe status
```

## ConvertTo-WarpClash.ps1 — 一键生成 Clash 临时订阅

自动化完成 usque 注册/生成 → 解析配置 → 构建完整 Clash YAML → 部署到 Cloudflare 临时 Workers。

```powershell
# 单账号
.\ConvertTo-WarpClash.ps1

# 多账号，生成多个节点
.\ConvertTo-WarpClash.ps1 -Count 3
```

**前提：** 需要 Node.js (npx)，首次运行会自动下载 wrangler。

**输出：** `https://warp-clash-xxxx.xxx.workers.dev/clash-warp.yaml`（60 分钟有效）

## 参考链接

- wgcf 源码/文档：<https://github.com/ViRb3/wgcf/>

## 开发注意事项

- **语言**：项目主要使用中文沟通。
- **wgcf.exe 位于仓库根目录**，所有命令以仓库根目录为工作目录执行。
- `usque register` 会创建 `config-masque.json`（MASQUE 配置）。
- usque 首次注册需要接受 ToS，用 `"y" | usque register` 管道输入。
- PowerShell `.NET` 正则默认不跨行匹配 `\n`，需加 `(?s)` 标志。
- Cloudflare 临时 Worker 名称只接受小写字母和数字。
- 临时部署 URL 格式为 `{project}.{account}.workers.dev`（含子域名）。
- 转换为 Clash 订阅时需解析 MASQUE `config.json`，映射为 Clash 的 `proxies` 配置（类型 `masque`）。
- MASQUE 的 public-key 需从 PEM 格式中去掉头部/尾部和新行，拼接为单行 base64。

## 避免的误区

- 不要提交 `config-masque*.json` 到版本控制。
- 多账号运行时生成的 `config-masque-2.json` 等文件不会被自动清理，注意 .gitignore。
