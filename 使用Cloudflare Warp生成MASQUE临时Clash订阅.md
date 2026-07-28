# 使用 Cloudflare Warp 一键生成 MASQUE 临时 Clash 订阅

## 前言

Cloudflare Warp 是一个免费且快速的网络加速服务。本文将介绍如何利用开源工具 `usque` 和 `wgcf` 注册 Warp 账号，并将其转换为 Clash 订阅链接，实现**国内直连 + 国外代理**的分流策略。

生成的订阅通过 Cloudflare Workers 临时部署，无需服务器，**60 分钟自动销毁**，适合临时使用或测试。

---

## 原理

```
usque register → config-masque.json（MASQUE 密钥）
       ↓
 解析 JSON → 构建 Clash YAML
       ↓
 wrangler deploy --temporary → 临时 workers.dev 订阅链接
       ↓
 Clash 客户端拉取订阅 → 开箱即用
```

---

## 所需文件

| 文件 | 来源 | 说明 |
|------|------|------|
| `usque.exe` | [Diniboy1123/usque](https://github.com/Diniboy1123/usque) | 开源 Warp MASQUE 客户端，MIT 协议 |
| `ConvertTo-WarpClash.ps1` | 本文编写 | 一键生成脚本 |
| `生成订阅.bat` | 本文编写 | 双击运行 |

> `usque.exe` 可在其 GitHub Releases 页面下载 Windows 版本。

---

## 使用教程

### 1. 准备环境

- Windows 系统（脚本基于 PowerShell 5.1）
- 安装 [Node.js](https://nodejs.org/)（用于 `npx wrangler`）
- 将 `usque.exe` 和 `ConvertTo-WarpClash.ps1` 放在同一目录

### 2. 双击运行

双击 `生成订阅.bat`，按提示操作：

```
已有账号文件 config-masque.json，是否注册新账号？(y/n):
  → 首次使用输入 y 注册新账号
  → 以后输入 n 使用已有账号

是否上传到 Cloudflare 生成临时订阅链接？(y/n):
  → 输入 y：部署到 Workers，获得临时订阅 URL
  → 输入 n：仅保存到本地 clash-warp.yaml
```

### 3. 在 Clash 中使用

若选择上传，输出类似：

```
✅ 已生成 1 个 MASQUE 节点
✅ 订阅链接: https://warp-clash-xxxx.xxx.workers.dev/clash-warp.yaml
⏳ 该链接 60 分钟后失效
```

将订阅链接填入 Clash 客户端即可。

---

## Clash 配置说明

生成的 YAML 配置包含：

- **通用设置**：mixed-port、allow-lan、ipv6、unified-delay、tcp-concurrent、geodata-mode
- **DNS 分流**：国内域名走 Alidns，其他走 Cloudflare DNS
- **代理组**：SELECT（手动选择）、全球直连、全球拦截
- **分流规则**：GEOIP/GEOSITE 智能分流

```
国内域名/IP → 全球直连（直连）
被墙域名   → SELECT（可选 Warp）
其余流量   → SELECT（可选 Warp）
```

> 此配置模板参考自 Clash 社区常见配置，已标注引用来源。

---

## 引用与致谢

本项目和文章基于以下开源项目：

1. **usque** — Cloudflare Warp MASQUE 协议的开源实现
   - 仓库：<https://github.com/Diniboy1123/usque>
   - 协议：MIT License
   - 用途：注册 Warp MASQUE 账号，生成 MASQUE 配置

2. **wgcf** — Cloudflare Warp WireGuard 配置生成工具
   - 仓库：<https://github.com/ViRb3/wgcf>
   - 协议：MIT License
   - 用途：注册 Warp WireGuard 账号（项目早期版本使用）

3. **Cloudflare WARP** — <https://cloudflare.com/warp>
   - 提供免费网络加速服务

4. **Cloudflare Workers** — <https://workers.cloudflare.com>
   - 提供临时静态站点部署（`--temporary` 模式）

5. **Clash/Mihomo 社区** — Clash 配置模板参考了社区常见实践，代理组和分流规则为标准 Clash 格式

---

## 许可证

本文采用 MIT License 发布。

`ConvertTo-WarpClash.ps1` 和 `生成订阅.bat` 同样采用 MIT License，欢迎自由使用和修改。

---

## 注意事项

- `config-masque.json` 包含私钥，**不要提交到版本控制**，已包含在 `.gitignore` 建议中
- 多账号模式下生成的 `config-masque-2.json` 等文件不会被自动清理
- 临时订阅链接 60 分钟有效，过期后需重新生成
- 生成的 Clash 配置需要 mihomo/Clash.Meta 内核（支持 MASQUE 类型）
