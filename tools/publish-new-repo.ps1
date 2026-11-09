# 新建 GitHub 仓库并发布（一个命令搞定）
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tools\publish-new-repo.ps1 -Token ghp_xxx -RepoName Kaze-SLauncher
#
# 做的四件事：
#   1. 用 API 在你的账号下创建仓库（已存在则复用）
#   2. 把当前目录的 main 分支推上去
#   3. 创建 Release（tag v0.11.1）
#   4. 把 dist/ 里的已签名 APK 作为 Release 资产上传
#
# PAT 权限：classic 选 repo；fine-grained 选 Administration(读写) + Contents(读写) + Releases(读写)。

param(
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$RepoName = "Kaze-SLauncher",
    [string]$Description = "Android Minecraft Java/基岩版服务器启动器：模组/资源包/地图下载、离线控制台、客户端同步、Tailscale/樱花映射/frp、远程管理",
    [switch]$Private,
    [string]$Tag = "v0.11.1",
    [string]$ApkPath = "dist/Kaze-SLauncher-0.11.1-arm64-signed.apk"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (-not $Token) {
    Write-Error "缺少 Token：-Token 或环境变量 GITHUB_TOKEN（需创建仓库与 Releases 的写权限）"
    exit 1
}

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
$git = if ($gitCmd) { $gitCmd.Source } else { $null }
if (-not $git) {
    foreach ($c in @(
        "C:\Program Files\Git\cmd\git.exe",
        (Join-Path $env:USERPROFILE "Documents\deepseek-harness\default-workspace\kaze\.buildtools\mingit\cmd\git.exe")
    )) { if (Test-Path $c) { $git = $c; break } }
}
if (-not $git) { Write-Error "找不到 git，请先安装 Git"; exit 1 }

$headers = @{
    Authorization = "Bearer $Token"
    "User-Agent"  = "Kaze-SLauncher-Publisher"
    Accept        = "application/vnd.github+json"
}

# ── 0. 如果不是 git 仓库（直接从 zip 解压的情况），就地初始化 ──
if (-not (Test-Path ".git")) {
    Write-Host "→ 初始化本地仓库（main）"
    & $git init -q -b main
    & $git config user.name "Kaze SLauncher"
    & $git config user.email "bot@kaze-slauncher.invalid"
    & $git add -A
    & $git commit -q -m "Kaze SLauncher 0.11.1：源码 + 已签名安装包 + 使用说明 + 赞助"
}
# ── 当前账号 ──
$me = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers
$Owner = $me.login
Write-Host "→ 账号：$Owner"

# ── 1. 创建仓库（已存在则复用）──
Write-Host "→ 创建/复用仓库 $Owner/$RepoName"
$repoBody = @{
    name        = $RepoName
    description = $Description
    private     = [bool]$Private
    has_issues  = $true
    has_wiki    = $true
} | ConvertTo-Json
try {
    Invoke-RestMethod -Method Post -Uri "https://api.github.com/user/repos" `
        -Headers $headers -Body $repoBody -ContentType "application/json" | Out-Null
    Write-Host "  已创建"
} catch {
    Write-Host "  仓库已存在（继续使用）"
}

# ── 2. 推送 main ──
Write-Host "→ 推送 main"
$remote = "https://$($Token)@github.com/$Owner/$RepoName.git"
& $git remote remove origin 2>$null
& $git remote add origin $remote
& $git push -u origin main
if ($LASTEXITCODE -ne 0) { Write-Error "推送失败：检查 PAT 是否具备 Contents 写权限"; exit 1 }

# ── 3. Release ──
Write-Host "→ 创建 Release $Tag"
$notes = @"
Kaze SLauncher $Tag

安装包在下方 Assets 里（arm64 / 已签名 / versionCode 36）。

主要功能
- 资源中心：模组 / 插件 / 资源包 / 地图 / 基岩版，全部带图标；官方 Modrinth + MCIM 镜像自动回退
- 客户端专用模组检测（可多选停用）
- 崩溃自动重启
- 公网与远程：Tailscale / 樱花映射（访问密钥登录）/ 自建 frp / 远程管理 API
- 客户端模组同步：整合包 .zip/.mrpack + 增量脚本

文档：docs/使用说明.md；赞助：README.md「☕ 赞助支持」
"@
$releaseBody = @{
    tag_name         = $Tag
    target_commitish = "main"
    name             = "Kaze SLauncher $Tag"
    body             = $notes
    draft            = $false
    prerelease       = $false
} | ConvertTo-Json

$release = $null
try {
    $release = Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/$Owner/$RepoName/releases" `
        -Headers $headers -Body $releaseBody -ContentType "application/json"
} catch {
    $all = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$RepoName/releases" -Headers $headers
    $release = $all | Where-Object { $_.tag_name -eq $Tag } | Select-Object -First 1
    if (-not $release) { throw }
    Write-Host "  复用已有 Release"
}

# ── 4. 上传 APK ──
if (Test-Path $ApkPath) {
    Write-Host "→ 上传 $(Split-Path $ApkPath -Leaf)（$([math]::Round((Get-Item $ApkPath).Length / 1MB, 1)) MB）"
    $name = [uri]::EscapeDataString((Split-Path $ApkPath -Leaf))
    Invoke-RestMethod -Method Post `
        -Uri "https://uploads.github.com/repos/$Owner/$RepoName/releases/$($release.id)/assets?name=$name" `
        -Headers $headers -ContentType "application/vnd.android.package-archive" `
        -InFile $ApkPath | Out-Null
} else {
    Write-Host "  跳过 APK：找不到 $ApkPath"
}

Write-Host ""
Write-Host "完成："
Write-Host "  仓库： https://github.com/$Owner/$RepoName"
Write-Host "  发行： https://github.com/$Owner/$RepoName/releases/tag/$Tag"
