//! AI Audiobook Win Spike — Tauri 主进程（最小壳）
//!
//! 派生自 tauri-sidecar-template（老板模板，init-project.sh 生成后精简）。
//! spike 命题：验证模板骨架在 windows-latest 能产出 x64 NSIS 安装包。
//!
//! sidecar 生命周期管理（Python 子进程 spawn/健康检查/三重兜底清理）属完整
//! 工程阶段适配范围（TODO: uvloop/os.killpg/lsof 等 5 条 Windows 失败链），
//! 不在本 spike 验证范围，故此壳不含 sidecar 模块。

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
