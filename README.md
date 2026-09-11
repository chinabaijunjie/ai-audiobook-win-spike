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

## 结论（2026-09-11，最终 run [34546505831](https://github.com/chinabaijunjie/ai-audiobook-win-spike/actions/runs/34546505831) 双 job 全绿）

**两条链路均验证通过，spike 命题成立。**

### 链路 1：CosyVoice 依赖（deps-spike，9m52s）

- **176 / 178 通过**（逐包安装，Python 3.10，CPU torch 2.3.1）
- **关键 C 扩展导入验证 22/24 通过**（pyworld、numba、librosa、onnxruntime、cffi、cryptography、Cython、grpc、tiktoken、tokenizers 等全部通过）——spike 核心命题：pyworld 等 C 扩展在 Windows x64 **可安装可导入**；仅 whisper、uvloop 导入失败，均为各自安装失败的直接后果，非平台兼容性问题
- 导入名勘误：pyworld 顶层导入名是 `pyworld`（WORLD 是其包装的 C 库名），验证脚本首版误用 `import world` 曾误报失败，已修正
- 失败 2 项，均有明确路径：

| 包 | 根因 | 修复方向 |
|----|------|----------|
| `openai-whisper==20231117` | 构建隔离环境新版 setuptools 移除 `pkg_resources`，setup.py 挂在 import 阶段（非平台问题） | 构建环境预装 `setuptools<81` 或升级 whisper 版本 |
| `uvloop==0.22.1` | 平台硬性不支持（`uvloop does not support Windows`），预期内 | sidecar 代码适配 asyncio ProactorEventLoop（完整工程阶段 5 条失败链之一） |

### 链路 2：Tauri 壳 NSIS（tauri-nsis，6m43s）

- x64 NSIS 安装包产出 ✅（artifact `nsis-x64-installer`，1.85 MB）
- 模板派生壳（去 sidecar 模块）零改动编译通过

### 对完整工程的含义

- 依赖风险已排除，Windows 版完整适配可启动（uvloop 替换 / os.killpg / lsof 进程清理 / 二进制 / 打包脚本 5 条失败链 + whisper 构建修复），评估维持 1-2 周
- 本仓 workflow 可直接复用为完整工程期的 CI 依赖验证基准

> 结论已回填 ai-audiobook `wiki/dev/TODO.md` Windows 版打包行（2026-09-11）。

## 关联

- ai-audiobook `wiki/dev/TODO.md` Windows 版打包条目（spike 结论回填处）
- `tauri-sidecar-template` — 壳的派生来源（新工程模板铁律）
