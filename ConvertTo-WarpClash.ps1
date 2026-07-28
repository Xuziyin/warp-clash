param(
    [int]$Count = 1
)

$UsquePath = Join-Path $PSScriptRoot "usque.exe"
$RandomId = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
$TempDir = Join-Path $env:TEMP "warp-clash-$RandomId"

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

if (-not (Test-CommandExists "npx")) {
    Write-Error "npx 未找到，请安装 Node.js"
    exit 1
}

if (-not (Test-Path $UsquePath)) {
    Write-Error "usque.exe 未找到"
    exit 1
}

function Strip-PemHeaders {
    param([string]$PemContent)
    $lines = $PemContent -split "`n"
    $b64 = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -and $trimmed -notlike '-----BEGIN*' -and $trimmed -notlike '-----END*') {
            $b64 += $trimmed
        }
    }
    return $b64 -join ''
}

try {
    $nodes = @()
    for ($i = 1; $i -le $Count; $i++) {
        $configFile = if ($Count -eq 1) { "config-masque.json" } else { "config-masque-$i.json" }
        $needRegister = -not (Test-Path $configFile)

        if (-not $needRegister) {
            Write-Host "[$i/$Count] 已有账号文件 $configFile，是否注册新账号？(y/n): " -NoNewline
            $input = Read-Host
            if ($input -eq 'y') {
                Remove-Item -Path $configFile -Force
                $needRegister = $true
            }
        }

        if ($needRegister) {
            Write-Host "[$i/$Count] 注册新 Warp 账号..."
            "y" | & $UsquePath register -c (Join-Path $PSScriptRoot $configFile) 2>&1 | Out-Null
            if (-not (Test-Path $configFile)) { Write-Error "MASQUE 注册失败"; exit 1 }
        }

        $cfg = Get-Content -Raw -Path $configFile | ConvertFrom-Json
        $nodes += @{
            Name       = "Warp-Masque-$i"
            Server     = $cfg.endpoint_v4
            Port       = 443
            IP         = $cfg.ipv4 + "/32"
            IPv6       = $cfg.ipv6 + "/128"
            PrivateKey = $cfg.private_key
            PublicKey  = Strip-PemHeaders -PemContent $cfg.endpoint_pub_key
            MTU        = 1280
            SNI        = "consumer-masque.cloudflareclient.com"
            CC         = "bbr"
        }
    }

    Write-Host "生成 Clash 配置..."
    $null = New-Item -ItemType Directory -Path $TempDir -Force
    $yamlPath = Join-Path $TempDir "clash-warp.yaml"

    $proxiesYaml = @()
    foreach ($n in $nodes) {
        $proxiesYaml += "  - name: $($n.Name)"
        $proxiesYaml += "    type: masque"
        $proxiesYaml += "    server: $($n.Server)"
        $proxiesYaml += "    port: $($n.Port)"
        $proxiesYaml += "    ip: $($n.IP)"
        $proxiesYaml += "    ipv6: $($n.IPv6)"
        $proxiesYaml += "    private-key: $($n.PrivateKey)"
        $proxiesYaml += "    public-key: $($n.PublicKey)"
        $proxiesYaml += "    mtu: $($n.MTU)"
        $proxiesYaml += "    sni: $($n.SNI)"
        $proxiesYaml += "    congestion-controller: $($n.CC)"
    }

    $fullYaml = @"
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
$($proxiesYaml -join "`n")
"@

    $fullYaml | Set-Content -Path $yamlPath -Encoding UTF8

    Write-Host "`n是否上传到 Cloudflare 生成临时订阅链接？(y/n): " -NoNewline
    $upload = Read-Host

    if ($upload -eq 'y') {
        @"
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Warp Clash</title></head>
<body><h1>Warp Clash Subscription</h1></body>
</html>
"@ | Set-Content -Path (Join-Path $TempDir "index.html") -Encoding UTF8

        Write-Host "部署到 Cloudflare..."
        $compatDate = Get-Date -Format "yyyy-MM-dd"
        $output = & npx --yes wrangler@latest deploy $TempDir --name "warp-clash-$RandomId" --temporary --compatibility-date $compatDate 2>&1
        $outputString = $output -join "`n"

        $urlRegex = 'https://warp-clash-[^\s]+\.workers\.dev'
        $match = [regex]::Match($outputString, $urlRegex)

        if ($match.Success) {
            Write-Host "`n✅ 已生成 $Count 个 MASQUE 节点"
            Write-Host "✅ 订阅链接: $($match.Value)/clash-warp.yaml"
            Write-Host "⏳ 该链接 60 分钟后失效`n"
        } else {
            Write-Host "`n部署输出:"
            Write-Host $outputString
            Write-Error "无法提取部署 URL"
            exit 1
        }
    } else {
        $localPath = Join-Path $PSScriptRoot "clash-warp.yaml"
        Copy-Item -Path $yamlPath -Destination $localPath -Force
        Write-Host "`n✅ 已保存到: $localPath`n"
    }
} finally {
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}