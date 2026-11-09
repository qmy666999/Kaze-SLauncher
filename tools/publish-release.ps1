# 一键发布到 GitHub（分支 + Release + APK 资产）
#
# 用法（两种任选）：
#   1) 直接把访问密钥作为参数： .\publish-release.ps1 -Token ghp_xxx
#   2) 先把 GITHUB_TOKEN 设成用户环境变量，再运行： .\publish-release.ps1
#
# 需要：仓库写权限的 PAT（classic: repo；fine-grained: Contents + Releases 读写）
# 说明：PowerShell 5.1 自带 Invoke-RestMethod 即可，不依赖 gh CLI。

param(
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$Owner = "0Sakura721",
    [string]$Repo = "Kaze-SLauncher",
    [string]$Branch = "feat/v0.10-content-hub",
    [string]$Tag = "v0.11.1",
    [string]$ApkPath = "dist/Kaze-SLauncher-0.11.1-arm64-signed.apk"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (-not $Token) {
    Write-Error "缺少 Token：请传 -Token 或设置环境变量 GITHUB_TOKEN（需 repo / Contents+Releases 写权限）"
    exit 1
}
if (-not (Test-Path $ApkPath)) {
    Write-Error "找不到安装包：$ApkPath（请在仓库根目录运行本脚本）"
    exit 1
}

# 优先用 PATH 里的 git，没有就用本机 MinGit
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
$git = if ($gitCmd) { $gitCmd.Source } else { $null }
if (-not $git) {
    $candidate = Join-Path $env:USERPROFILE "Documents\deepseek-harness\default-workspace\kaze\.buildtools\mingit\cmd\git.exe"
    if (Test-Path $candidate) { $git = $candidate }
}
if (-not $git) {
    Write-Error "找不到 git：请先安装 Git，或把本脚本放进已配置 git 的环境运行"
    exit 1
}

$remote = "https://$($Token)@github.com/$Owner/$Repo.git"

Write-Host "→ 推送分支 $Branch"
& $git remote set-url origin $remote
& $git push -u origin $Branch
if ($LASTEXITCODE -ne 0) { Write-Error "git push 失败（检查 Token 权限）"; exit 1 }

$headers = @{
    Authorization          = "Bearer $Token"
    "User-Agent"           = "Kaze-SLauncher-Publisher"
    Accept                 = "application/vnd.github+json"
}

Write-Host "→ 创建/更新 Release $Tag"
$notes = @"
Kaze SLauncher $Tag

- 资源中心：模组 / 插件 / 资源包 / 地图 / 基岩版，全部带图标
- 搜索与推荐：官方 Modrinth + MCIM 镜像自动回退
- 客户端专用模组检测（可多选停用）
- 崩溃自动重启开关
- 公网与远程：Tailscale / 樱花映射（访问密钥登录）/ 自建 frp / 远程管理 API
- 安装包为 arm64、已签名（versionCode 36）
"@
$releaseBody = @{
    tag_name         = $Tag
    target_commitish = $Branch
    name             = "Kaze SLauncher $Tag"
    body             = $notes
    draft            = $false
    prerelease       = $false
} | ConvertTo-Json

$release = $null
try {
    $release = Invoke-RestMethod -Method Post `
        -Uri "https://api.github.com/repos/$Owner/$Repo/releases" `
        -Headers $headers -Body $releaseBody -ContentType "application/json"
} catch {
    # 已存在则取现有 release（重复运行不会失败）
    Write-Host "  发布已存在，改用现有 Release"
    $all = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/$Owner/$Repo/releases" -Headers $headers
    $release = $all | Where-Object { $_.tag_name -eq $Tag } | Select-Object -First 1
    if (-not $release) { throw }
}

Write-Host "→ 上传 $ApkPath（约 $([math]::Round((Get-Item $ApkPath).Length / 1MB, 1)) MB）"
$name = [uri]::EscapeDataString((Split-Path $ApkPath -Leaf))
Invoke-RestMethod -Method Post `
    -Uri "https://uploads.github.com/repos/$Owner/$Repo/releases/$($release.id)/assets?name=$name" `
    -Headers $headers -ContentType "application/vnd.android.package-archive" `
    -InFile $ApkPath | Out-Null

Write-Host ""
Write-Host "完成："
Write-Host "  分支： https://github.com/$Owner/$Repo/tree/$Branch"
Write-Host "  发行： https://github.com/$Owner/$Repo/releases/tag/$Tag"
