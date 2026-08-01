# 使用 Cloudflare Warp 一键生成 MASQUE 临时 Clash 订阅

## 前言

Cloudflare Warp 是一个免费且快速的网络加速服务。本文将介绍如何利用开源工具一键注册 Warp 账号，并将其转换为 Clash 订阅链接，实现**国内直连 + 国外代理**的分流策略。

生成的订阅通过 Cloudflare Workers 临时部署，无需服务器，**60 分钟自动销毁**。

项目地址：<https://github.com/Xuziyin/warp-clash>

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

## 下载

从 GitHub Releases 下载最新版 zip：

```
https://github.com/Xuziyin/warp-clash/releases
```

解压后包含：

| 文件 | 说明 |
|------|------|
| `usque.exe` | Cloudflare Warp MASQUE 客户端，来自 [Diniboy1123/usque](https://github.com/Diniboy1123/usque) |
| `ConvertTo-WarpClash.ps1` | 一键生成脚本 |
| `生成订阅.bat` | 双击启动器 |

---

## 使用教程

### 1. 准备环境

- Windows 系统
- 安装 [Node.js](https://nodejs.org/)（用于 `npx wrangler`）

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

---

## 引用与致谢

1. **usque** — Cloudflare Warp MASQUE 协议的开源实现
   - 仓库：<https://github.com/Diniboy1123/usque>
   - 协议：MIT License

2. **wgcf** — Cloudflare Warp WireGuard 配置生成工具
   - 仓库：<https://github.com/ViRb3/wgcf>
   - 协议：MIT License

3. **Cloudflare WARP** — <https://cloudflare.com/warp>

4. **Cloudflare Workers** — <https://workers.cloudflare.com>

5. **Clash/Mihomo 社区** — 配置模板参考社区常见实践

---

## 注意事项

- `config-masque.json` 包含私钥，**不要泄露或提交到版本控制**
- 临时订阅链接 **60 分钟有效**，过期后需重新生成
- 生成的 Clash 配置需要 **mihomo/Clash.Meta** 内核（支持 MASQUE 类型）
- 如需更换 Warp 账号，删掉 `config-masque.json` 重新运行即可

---

项目地址：<https://github.com/Xuziyin/warp-clash>
欢迎 Star、Issue、PR。
