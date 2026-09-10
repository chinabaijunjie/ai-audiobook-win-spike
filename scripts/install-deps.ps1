# install-deps.ps1 — CosyVoice 依赖逐包安装记录（spike 核心脚本）
# 逐包 pip install，失败继续，记录 PASS/FAIL + 耗时，输出 GITHUB_STEP_SUMMARY 汇总表
$ErrorActionPreference = 'Continue'

# 读取清单，排除 torch/torchaudio（CPU 版已在前面步骤用专用 index 安装）
$pkgs = Get-Content requirements-cosyvoice.txt |
    Where-Object { $_ -match '^[A-Za-z]' -and $_ -notmatch '^(torch==|torchaudio==)' }

Write-Host "=== 共 $($pkgs.Count) 个包，开始逐包安装 ==="

$results = @()
$failed = @()
$i = 0

foreach ($pkg in $pkgs) {
    $i++
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $output = pip install $pkg 2>&1
    $sw.Stop()
    $ok = ($LASTEXITCODE -eq 0)
    $secs = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $status = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Host "[$i/$($pkgs.Count)] $status  $pkg  (${secs}s)"

    $results += [PSCustomObject]@{ Package = $pkg; Status = $status; Seconds = $secs }

    if (-not $ok) {
        $failed += $pkg
        Add-Content -Path failed-packages.txt -Value $pkg
        Write-Host "--- 错误尾部（$pkg）---" -ForegroundColor Yellow
        $output | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" }
    }
}

# 汇总
$passCount = ($results | Where-Object Status -eq 'PASS').Count
$failCount = ($results | Where-Object Status -eq 'FAIL').Count
$totalSecs = [math]::Round(($results | Measure-Object -Property Seconds -Sum).Sum, 0)

Write-Host ""
Write-Host "=== 安装汇总: PASS=$passCount FAIL=$failCount 总耗时=${totalSecs}s ==="

# 写 GITHUB_STEP_SUMMARY（Markdown 表）
$summary = @()
$summary += "## CosyVoice 依赖 Windows 安装结果"
$summary += ""
$summary += "| 结果 | 数量 |"
$summary += "|------|------|"
$summary += "| ✅ PASS | $passCount |"
$summary += "| ❌ FAIL | $failCount |"
$summary += "| 总耗时 | ${totalSecs}s |"
$summary += ""

if ($failCount -gt 0) {
    $summary += "### 失败清单"
    $summary += ""
    $summary += "| 包 | 耗时 |"
    $summary += "|----|------|"
    foreach ($f in ($results | Where-Object Status -eq 'FAIL')) {
        $summary += "| ``$($f.Package)`` | $($f.Seconds)s |"
    }
    $summary += ""
}

$summary += "### 全量明细"
$summary += ""
$summary += "| 包 | 结果 | 耗时 |"
$summary += "|----|------|------|"
foreach ($r in $results) {
    $icon = if ($r.Status -eq 'PASS') { '✅' } else { '❌' }
    $summary += "| ``$($r.Package)`` | $icon $($r.Status) | $($r.Seconds)s |"
}
$summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8

# 关键 C 扩展导入验证（包名→import 名不同的单独映射）
Write-Host ""
Write-Host "=== 关键 C 扩展导入验证 ==="
$critical = @{
    'numpy' = 'numpy'; 'scipy' = 'scipy'; 'pandas' = 'pandas'
    'pyworld' = 'world'; 'numba' = 'numba'; 'llvmlite' = 'llvmlite'
    'librosa' = 'librosa'; 'soundfile' = 'soundfile'; 'soxr' = 'soxr'
    'onnx' = 'onnx'; 'onnxruntime' = 'onnxruntime'; 'cffi' = 'cffi'
    'Cython' = 'Cython'; 'grpcio' = 'grpc'; 'cryptography' = 'cryptography'
    'psutil' = 'psutil'; 'pydantic_core' = 'pydantic_core'
    'tokenizers' = 'tokenizers'; 'safetensors' = 'safetensors'
    'pyarrow' = 'pyarrow'; 'regex' = 'regex'; 'tiktoken' = 'tiktoken'
    'openai-whisper' = 'whisper'; 'uvloop' = 'uvloop'
}

$importResults = @()
foreach ($pkgName in ($critical.Keys | Sort-Object)) {
    # 只验证清单中存在的包
    if ($pkgs -notcontains $pkgName) { continue }
    $importName = $critical[$pkgName]
    $r = python -c "import $importName; print('ok')" 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    $status = if ($ok) { '✅ 可导入' } else { '❌ 导入失败' }
    Write-Host "$status  $pkgName (import $importName)"
    if (-not $ok) {
        $errLine = ($r | Select-Object -Last 1)
        Write-Host "    错误: $errLine"
    }
    $importResults += [PSCustomObject]@{ Package = $pkgName; ImportName = $importName; Status = $status }
}

# 导入验证追加到 summary
$summary2 = @()
$summary2 += ""
$summary2 += "### 关键 C 扩展导入验证"
$summary2 += ""
$summary2 += "| 包 | import | 结果 |"
$summary2 += "|----|--------|------|"
foreach ($r in $importResults) {
    $summary2 += "| ``$($r.Package)`` | ``$($r.ImportName)`` | $($r.Status) |"
}
$summary2 | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8

# 有失败包时以非零退出，让 job 标红但表格已完整记录（失败清单是合法 spike 结论）
if ($failCount -gt 0) {
    Write-Host "::warning::有 $failCount 个包安装失败，详见 Step Summary 表格"
}
