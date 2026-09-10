# ai-audiobook-win-spike

Windows 打包可行性 spike：**独立最小验证仓**，验证两条链路在 `windows-latest`（4核16G 免费）能否跑通。

- **链路 1（核心命题）**：ai-audiobook sidecar 的 CosyVoice 全量依赖（180 项锁定版本）能否在 Windows x64 安装成功——重点观察 pyworld 等 C 扩展编译
- **链路 2**：从 `tauri-sidecar-template` 派生的最小 Tauri 壳能否产出 x64 NSIS 安装包

## 为什么是独立仓

ai-audiobook 主仓托管在 Gitee。主仓代码一行不上 GitHub，避免「核心代码二次托管」边界问题。本仓内容只有：

- `requirements-cosyvoice.txt` — 依赖锁定清单（从 sidecar 原样提取，纯 PyPI 包名+版本，无内部路径/密钥）
- `.github/workflows/windows-spike.yml` — 双 job CI
- `src-tauri/` + 前端最小壳 — 模板派生（init-project.sh 生成后精简，去掉 sidecar 模块——Windows 进程管理适配属完整工程阶段，不在 spike 范围）

仓库无任何敏感内容，故用**公开仓**（公开仓 Actions 免费不限量；若后续发现敏感内容则降级私仓）。

## 运行方式

推送到 GitHub 后 Actions 自动运行（push to main / 手动 workflow_dispatch）：

| Job | 内容 | 预期 |
|-----|------|------|
| `deps-spike` | CPU torch → 180 包逐包安装（失败继续）→ 关键 C 扩展导入验证 | 全绿或明确失败清单（两者均为合法 spike 结论） |
| `tauri-nsis` | npm install → cargo tauri build → 上传 NSIS artifact | x64 NSIS 安装包产物 |

每包安装结果（PASS/FAIL + 耗时）写入 workflow Step Summary 表格。

## 结论

> 待 CI 运行后填写。

## 关联

- ai-audiobook `wiki/dev/TODO.md` Windows 版打包条目（spike 结论回填处）
- `tauri-sidecar-template` — 壳的派生来源（新工程模板铁律）
