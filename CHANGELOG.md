# Changelog

All notable changes to PhantomKnob will be documented in this file.

## [0.9.1] - 2026-08-05

### 🇨🇳 中文
#### 🚀 新功能与优化
- 新增【软件更新】设置控制面板，支持查看上次检查时间与手动检查更新
- 支持后台自动检测更新与静默下载体验
- 全面完善软件界面与通知的中英文本地化支持
- 支持触控板设备重新检测与启动时自动恢复前次激活状态
#### 🐛 问题修复
- 修复通用设置面板中软件更新卡片显示重复的问题
- 优化通用设置面板的卡片层次分布，提升使用体验

---

### 🇺🇸 English
#### 🚀 Features & Improvements
- Added Software Update settings panel with manual check & automatic download options
- Supported automatic background update detection and release verification
- Completed full English and Simplified Chinese localization across settings and dialogs
- Supported asynchronous trackpad re-detection and startup state restoration
#### 🐛 Bug Fixes
- Fixed duplicate software update section card in General Settings
- Refined General Settings card layout and visual hierarchy


## [0.9.0] - 2026-08-05

### 🇨🇳 中文
- **自动更新框架**：集成 Sparkle 2 自动更新机制，支持后台静默检测与一键重启安装。
- **设置界面整合**：通用设置面板新增【软件更新】板块，支持自动检查、后台下载开关及上次检查时间显示。
- **国际化多语言**：补齐软件更新与设置面板的完整中英文本地化翻译。
- **自动化发布脚本**：提供一键打包签名脚本 (`release_update.sh`) 与端到端升级测试脚本 (`test_update_flow.sh`)。

### 🇺🇸 English
- **Auto Update Framework**: Integrated Sparkle 2 automatic update engine supporting background check and one-click restart installation.
- **Settings UI Integration**: Added Software Update section into General Settings panel with auto-check, background download toggles, and last checked timestamp.
- **Bilingual Localization**: Added complete English and Simplified Chinese localizations for Software Update settings and alerts.
- **Release Automation**: Added one-click build/signing script (`release_update.sh`) and E2E mock update test script (`test_update_flow.sh`).

---

## [0.8.0] - 2026-07-22

### 🇨🇳 中文
- **全局旋钮控制模式**：支持触控板双指旋转手势控制系统与第三方应用中的滑块/调节盘。
- **多种旋钮模式**：支持固定模式、双环模式与无级变速旋钮模式。
- **专业软件适配**：支持针对 CapCut、DaVinci Resolve、Final Cut Pro 与 Logic Pro 的预设包。
- **功能特性**：支持 14 天全功能试用、开机自启、状态栏指示、Sentry 崩溃告警与 os.Logger 日志。

### 🇺🇸 English
- Global knob control mode with trackpad two-finger rotation gesture
- Support for AXSlider, AXProgressIndicator, AXScrollBar elements
- Multiple knob modes: Fixed, Double-Ring, Variable Speed
- Custom rules system (My Knobs)
- Pro App knob packs for DaVinci Resolve, Final Cut Pro, Logic Pro
- 14-day full-feature trial
- English and Chinese (Simplified) localization
- Status bar menu with state indicator
- Settings window with hotkey customization
- Three-step interactive user guide
- Launch at login support
- Crash reporting with Sentry (opt-out supported)
- Structured logging with os.Logger
