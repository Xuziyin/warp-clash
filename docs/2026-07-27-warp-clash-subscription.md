# Warp → Clash 临时订阅工具 设计文档

## 概述

一键式 PowerShell 脚本，自动执行 wgcf 注册/生成 WireGuard 配置文件，转换为完整 Clash YAML 配置，并通过 Cloudflare Wrangler `--temporary` 部署为临时订阅链接。

支持 `-Count` 参数注册多个 Warp 账号，产生多条 Warp 节点。

## 执行流程

```
ConvertTo-WarpClash.ps1 [-Count <N>]
  │
  ├─ [参数: -Count N, 默认 1]
  │
  ├─ 循环 i = 1..N:
  │   ├─ wgcf register --config wgcf-account-i.toml
  │   ├─ wgcf generate --config wgcf-account-i.toml --file wgcf-profile-i.conf
  │   ├─ 解析 wgcf-profile-i.conf
  │   │    ├─ [Interface] → PrivateKey, Address(IPv4), DNS, MTU
  │   │    └─ [Peer]      → PublicKey, Endpoint(host:port), AllowedIPs
  │   └─ 收集节点配置
  │
  ├─ 生成 clash-warp.yaml（模板见下）
  │
  ├─ 创建临时目录 $env:TEMP\warp-clash-<randomId>\
  │    ├─ index.html（占位）
  │    └─ clash-warp.yaml
  │
  ├─ npx wrangler deploy --temporary --name warp-clash-<randomId>
  │    └─ 从 stdout 提取 workers.dev URL
  │
  ├─ 清理临时目录
  │
  └─ 输出订阅链接
```

## 输出 Clash 配置模板

```yaml
mixed-port: 7890
allow-lan: true
bind-address: '*'
mode: rule
log-level: info
ipv6: true
unified-delay: true
tcp-concurrent: true
geodata-mode: true
geox-url:
  geoip: https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat
  geosite: https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat
geo-auto-update: true
geo-update-interval: 24
global-ua: clash.meta
hosts:
  dns.alidns.com: [223.5.5.5, 223.6.6.6, 2400:3200::1, 2400:3200:baba::1]
  doh.pub: [1.12.12.12, 120.53.53.53]
dns:
  enable: true
  listen: 0.0.0.0:1053
  cache-algorithm: arc
  enhanced-mode: redir-host
  prefer-h3: true
  ipv6: true
  respect-rules: true
  nameserver:
    - https://cloudflare-dns.com/dns-query#proxy=SELECT
  nameserver-policy:
    geosite:cn:
      - https://dns.alidns.com/dns-query
      - https://doh.pub/dns-query
  proxy-server-nameserver:
    - https://dns.alidns.com/dns-query
  fallback:
    - https://dns.alidns.com/dns-query
  fallback-filter:
    geoip: false
    ipcidr: []
    domain: []

proxy-groups:
  - name: SELECT
    type: select
    include-all: true
    proxies: [DIRECT]
    icon: "https://raw.githubusercontent.com/Koolson/Qure/master/IconSet/Color/Proxy.png"
  - name: 全球直连
    type: select
    include-all: true
    proxies: [DIRECT]
    icon: "https://raw.githubusercontent.com/Koolson/Qure/master/IconSet/Color/Direct.png"
  - name: 全球拦截
    type: select
    include-all: true
    proxies: [REJECT, SELECT, DIRECT]
    icon: "https://raw.githubusercontent.com/Koolson/Qure/master/IconSet/Color/Reject.png"

rules:
  - GEOIP,private,DIRECT
  - GEOSITE,private,DIRECT
  - GEOSITE,category-ads-all,全球拦截
  - GEOSITE,gfw,SELECT
  - GEOSITE,cn,全球直连
  - GEOIP,CN,全球直连
  - MATCH,SELECT

proxies:
  - name: Warp-1
    type: wireguard
    server: <[Peer] Endpoint IP>
    port: <[Peer] Endpoint Port>
    ip: <[Interface] Address IPv4>
    private-key: <[Interface] PrivateKey>
    public-key: <[Peer] PublicKey>
    udp: true
    mtu: 1280
```

当 `-Count N > 1` 时，生成 N 个节点 `Warp-1`、`Warp-2`…`Warp-N`，每个节点对应一个独立 Warp 账号。`include-all: true` 使所有节点自动出现在 proxy-group 的可选列表中。

### 分流逻辑

| 规则 | 行为 |
|------|------|
| `GEOSITE,cn,全球直连` | 国内域名 → 直连 |
| `GEOIP,CN,全球直连` | 国内 IP → 直连 |
| `GEOSITE,gfw,SELECT` | 被墙域名 → 用户选择（可选 Warp） |
| `MATCH,SELECT` | 其余 → 用户选择（可选 Warp） |

`include-all: true` 使 Warp 自动出现在所有 proxy-group 的可选列表中。

## Cloudflare 临时部署

| 步骤 | 命令 |
|------|------|
| 部署 | `npx wrangler deploy --temporary --name warp-clash-<randomId>` |
| 有效期 | 60 分钟（未认领则自动销毁） |
| 认领 | 如需保留，60 分钟内通过 claim URL 认领 |

依赖：Node.js (npx) 必须可用。脚本在入口处检测。

## 输出格式

```powershell
.\ConvertTo-WarpClash.ps1
# 输出：
# ✅ 已生成 3 个 Warp 节点
# ✅ 订阅链接: https://warp-clash-xxxx.workers.dev/clash-warp.yaml
# ⏳ 该链接 60 分钟后失效

# 注册多个账号：
.\ConvertTo-WarpClash.ps1 -Count 3
```

## WireGuard → Clash 字段映射

| wgcf-profile.conf | clash-warp.yaml | 说明 |
|-------------------|-----------------|------|
| `[Interface] PrivateKey` | `proxies[i].private-key` | WireGuard 私钥 |
| `[Interface] Address` | `proxies[i].ip` | 取 IPv4 地址（/32 格式） |
| `[Interface] DNS` | — | Clash DNS 已在模板配置 |
| `[Interface] MTU` | `proxies[i].mtu` | 默认 1280 |
| `[Peer] PublicKey` | `proxies[i].public-key` | 远端公钥 |
| `[Peer] Endpoint` | `proxies[i].server` + `proxies[i].port` | 拆分 host 和 port |
| `[Peer] AllowedIPs` | — | Clash 由 rules 控制路由 |
