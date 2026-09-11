# r1-probe.ps1 — R1 风险验证：GitHub runner → Gitee 私有仓拉源可行性（方案B §3 第 0 步）
# 前置：GitHub Secrets 已配置 GITEE_READONLY_TOKEN（最小 scope 只读令牌）
# 输出：clone 成败 + 各次尝试耗时 → GITHUB_STEP_SUMMARY；探测通过返回 0
# 安全：URL 含令牌，输出全部脱敏（脚本内替换 + GitHub Actions 对 Secrets 自动 mask 双保险）
param(
    [string]$GiteeRepo = $env:GITEE_REPO,
    [string]$Ref = $env:GITEE_REF
)
if (-not $GiteeRepo) { $GiteeRepo = 'wangyunbaijunjie/ai-audiobook' }
if (-not $Ref) { $Ref = 'master' }

$ErrorActionPreference = 'Continue'
$token = $env:GITEE_READONLY_TOKEN
if (-not $token) {
    Write-Host '::error::GITEE_READONLY_TOKEN 未配置（Secrets 占位尚未就绪，见方案 windows-packaging-plan.md §3 第 0 步）'
    exit 1
}

$url = "https://oauth2:$token@gitee.com/$GiteeRepo.git"
$results = @()
$success = $false
$okSecs = 0

for ($i = 1; $i -le 3; $i++) {
    if (Test-Path probe-clone) { Remove-Item -Recurse -Force probe-clone }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    # clone 输出逐行脱敏后打印（token → ***）
    $output = git clone --depth 1 --branch $Ref $url probe-clone 2>&1
    $exit = $LASTEXITCODE
    $sw.Stop()
    $secs = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $ok = ($exit -eq 0)
    $results += [PSCustomObject]@{ Attempt = $i; Status = $(if ($ok) { 'PASS' } else { 'FAIL' }); Seconds = $secs }
    Write-Host "[R1] 尝试 $i/3 $(if ($ok) { 'PASS' } else { 'FAIL' }) ${secs}s"
    if (-not $ok) {
        $output | Select-Object -Last 10 | ForEach-Object { Write-Host ($_ -replace [regex]::Escape($token), '***') }
        Start-Sleep -Seconds 5
    } else {
        $success = $true
        $okSecs = $secs
        # 仓库体积粗测（过境数据量参考）
        $sizeMB = [math]::Round((Get-ChildItem probe-clone -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
        Write-Host "[R1] depth1 检出体积 ≈ ${sizeMB}MB"
        break
    }
}

# 过境不驻留：清理 clone 目录
if (Test-Path probe-clone) { Remove-Item -Recurse -Force probe-clone }

# GITHUB_STEP_SUMMARY（Markdown 表）
$summary = @()
$summary += "## R1 探测结果：GitHub runner → Gitee 拉源"
$summary += ""
$summary += "| 仓库 | ref | 结果 |"
$summary += "|---|---|---|"
$summary += "| $GiteeRepo | ``$Ref`` | $(if ($success) { "✅ PASS（$okSecs}s）" } else { '❌ FAIL（3 次重试均失败）' }) |"
$summary += ""
$summary += "| 尝试 | 结果 | 耗时 |"
$summary += "|---|---|---|"
foreach ($r in $results) { $summary += "| $($r.Attempt) | $($r.Status) | $($r.Seconds)s |" }
$summary += ""
if ($success) {
    $summary += "结论：R1 通过，方案 B 可继续（§3 第 1 步骨架已就绪，直接触发 windows-release job）。"
} else {
    $summary += "结论：R1 失败 → 按纪律停下，出方案 A 请示（需老板升级铁律，不得自行切换）。"
}
$summary -join "`n" | Add-Content -Path $env:GITHUB_STEP_SUMMARY

if (-not $success) { exit 1 }
