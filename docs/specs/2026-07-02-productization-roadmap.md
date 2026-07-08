# PhantomKnob 产品化路线图

将 PhantomKnob 从当前开发原型转变为面向海外市场的独立付费 macOS 工具软件。

## 决策摘要

| 决策项 | 结论 |
|---|---|
| 产品定位 | 独立付费软件（类 BetterTouchTool） |
| 目标市场 | 英文优先，中文第二语言，最终全球化 |
| 收费模式 | Freemium：14天全功能试用 → 免费层（带限制）→ 付费解锁全功能 + Pro App 旋钮包 |
| 售卖渠道 | Paddle 或 LemonSqueezy |
| 更新机制 | 首发手动下载，后期集成 Sparkle |

## 当前状态

**已完成（可直接复用）：**
- 核心手势引擎（状态机、手势分类、5° 阈值检测、冷却期）
- 输入翻译系统（AX write / 滚轮 / 方向键 / 滑动，共 7 种）
- 目标检测（Accessibility API，支持 AXSlider / AXProgressIndicator / AXScrollBar）
- Scale 系统（固定 / 双环 / 无级变速）
- 规则库双层架构（内置 bundled-rules + 用户 my_knobs.json）
- 实时 Overlay UI
- Customizer HUD（1071 行，功能丰富）
- 状态栏菜单
- 设置窗口（热键 / 辅助功能 / 启动 / 触控板检测）
- 三步使用引导
- 开机启动（SMAppService）
- 25 个单元测试文件
- 构建 + 公证脚本（模板）

**代码规模：** ~8000 行 Swift / 49 个源文件 / 244 次 commit

---

## Phase 1：基础产品化（P0 硬阻塞）

预计工期：4-6 周

### 1.1 Hardened Runtime 与代码签名

**现状：**
- `project.yml` 中 `ENABLE_HARDENED_RUNTIME: NO`
- `PhantomKnob.entitlements` 仅声明了 sandbox=false
- `build_notarize.sh` 存在但使用占位值

**需要做的：**
1. 在 `project.yml` 中启用 `ENABLE_HARDENED_RUNTIME: YES`
2. 添加必要的 Hardened Runtime entitlements：
   - `com.apple.security.automation.apple-events` — Accessibility API 需要
   - `com.apple.security.device.input-monitoring` — 触控板事件监控（如果需要 Input Monitoring 权限）
3. 逐项测试启用 Hardened Runtime 后的功能回归：
   - 触控板事件能否正常监听
   - Accessibility API 读写是否正常
   - CGEvent 合成是否被阻止（scroll wheel / arrow key 注入）
   - 全局热键监听是否正常
4. 配置 Developer ID Application 证书
5. 补全 `build_notarize.sh` 中的真实证书 / Team ID / Apple ID 信息
6. 端到端验证：构建 → 签名 → 公证 → staple → 在全新 Mac 上安装运行

**关键风险：** CGEvent 注入（ScrollWheelTranslator / ArrowKeyTranslator）在 Hardened Runtime 下可能需要额外 entitlement 或行为变化，这是最大技术风险点，应最先验证。

### 1.2 App 图标与基础品牌

**现状：**
- Assets.xcassets 仅含空 Contents.json，无 AppIcon
- 状态栏用 SF Symbols（circle / circle.fill），无品牌辨识度
- 无品牌色彩体系

**需要做的：**
1. **App 图标设计**（1024×1024 源文件）
   - macOS 圆角矩形风格
   - 概念建议：触控板上旋钮手势的抽象表达
   - 需要生成全套尺寸：16/32/64/128/256/512/1024
   - 创建 `AppIcon.appiconset` 放入 Assets.xcassets
2. **状态栏图标**
   - 设计独特的 18×18 / 36×36 template 图标
   - 需要区分各状态：inactive / activated / knobing / cooling
   - 替换当前 StatusBarController 中的 SF Symbol 实现
3. **品牌色定义**
   - 主色 / 强调色 / 状态色（成功 / 警告 / 错误）

### 1.3 英文本地化（i18n）

**现状：**
- 所有 UI 字符串硬编码中文
- 无 `.lproj` 目录、无 `.strings` / String Catalog 文件
- 估计约 180 个需本地化字符串

**涉及文件：**
- StatusBarController.swift (~15 strings)
- SettingsView.swift (~25 strings)
- UserGuideView.swift (~40 strings)
- CustomizerHUDView.swift (~60 strings)
- OverlayView.swift (~10 strings)
- KnobPanelView.swift (~10 strings)
- 其他 Service / Model (~20 strings)

**实施步骤：**
1. 采用 Xcode 15+ 的 String Catalog（`.xcstrings`）方案
2. 将所有硬编码中文替换为 `String(localized:)` 调用
3. 创建 `en.lproj` 为默认语言
4. 创建 `zh-Hans.lproj` 保留当前中文翻译
5. 撰写高质量英文文案
6. 更新 Info.plist 中的 CFBundleDevelopmentRegion 为 `en`

### 1.4 许可证系统（Paddle / LemonSqueezy 集成）

**现状：** 零许可证基础设施

**推荐 Paddle**（更成熟的 macOS 生态）

**实施步骤：**
1. 注册 Paddle 开发者账号，创建产品
2. 集成 Paddle macOS SDK（通过 SPM 或手动嵌入）
3. 实现 `LicenseManager` 单例：
   - state: LicenseState (.trial / .expired / .free / .licensed)
   - trialDaysRemaining: Int
   - activate(licenseKey:) → Result
   - deactivate() → Result
   - validateOnline() → Result
   - isFeatureUnlocked(_: Feature) → Bool
4. 试用期追踪：首次启动时在 Keychain 写入安装日期
5. 许可证存储：Keychain（加密存储 license key + activation date）
6. 离线容忍：激活后允许 30 天离线使用

### 1.5 Feature Gating（功能分层机制）

**设计理念：** 免费用户可使用全部核心旋钮功能（所有旋钮类型、键盘快捷键、自定义规则、Pro App 旋钮包），以培养一致的用户习惯。付费差异化通过"体验摩擦"和"外观定制"实现，而非功能锁定。

**三层用户状态：**

| 功能 | Trial (14天) | Free | Licensed |
|---|---|---|---|
| 所有旋钮类型（固定/双环/无级变速） | ✅ | ✅ | ✅ |
| 键盘倍率快捷键 (2-9) | ✅ | ✅ | ✅ |
| 自定义规则 (My Knobs) | ✅ | ✅ | ✅ |
| Customizer HUD | ✅ | ✅ | ✅ |
| Pro App 旋钮包 | ✅ | ✅ | ✅ |
| **激活速度** | 即时 | ⚠️ 2 秒延迟 | 即时 |
| **会话时长** | 无限制 | ⚠️ 15 分钟后自动退出激活 | 无限制 |
| **Overlay 样式** | 全部可选 | 固定默认样式 | 自定义颜色/主题/尺寸 |
| **菜单栏** | 干净图标 | "Free" 标志 + 剩余时间倒计时 | 干净图标 |
| **iCloud 同步** | ✅ | ❌ | ✅ |
| **规则导出/分享** | ✅ | ❌ | ✅ |

**Free 层摩擦机制详述：**

1. **延迟激活（2秒）**
   - 按热键后 Overlay 显示 "Activating..." 倒计时 2 秒，然后进入 activated 状态
   - 实现位置：KnobStateManager 的 `inactive → activated` 转换中插入延迟
   - 高频用户每天按几十次热键，每次多等 2 秒形成持续摩擦

2. **15 分钟会话限时**
   - 从进入 `activated` 状态开始计时 15 分钟
   - 倒计时在菜单栏状态项实时显示（如 "Free · 12:34 remaining"）
   - 最后 2 分钟：菜单栏倒计时变为橙色警告
   - 最后 30 秒：Overlay 短暂闪现 "Session ending soon"
   - 到期：自动退出 `activated` → `inactive`，显示温和提示 "Session ended. Press ⌘⌥R to start a new session, or upgrade for unlimited use."
   - 可立即重新激活（走 2 秒延迟），无等待惩罚
   - 实现位置：KnobStateManager 中添加 sessionTimer

3. **固定 Overlay 样式**
   - 免费用户只有一种默认 Overlay 外观（标准灰白色调）
   - 无法自定义颜色、主题、透明度、尺寸
   - 设置中 Overlay 定制选项显示但加锁标记 + "Upgrade to customize"

4. **菜单栏标识**
   - 状态栏菜单第一项显示 "PhantomKnob Free" 而非 "PhantomKnob"
   - 菜单中包含 "Upgrade to Premium" 入口（打开 Paddle 购买页面）
   - 已激活时显示剩余时间倒计时

**实施要点：**
1. 创建 `LicenseState` 枚举和 `LicenseManager` 单例
2. 创建 `FeatureGate` 工具类，统一判断当前用户层级
3. KnobStateManager 中添加 `sessionTimer`（仅 Free 层生效）
4. StatusBarController 菜单动态更新倒计时
5. OverlayController 根据 LicenseState 决定是否允许样式定制
6. 到期提醒采用 gentle nudge 风格——信息性，不阻断

### 1.6 落地页与支付流程

1. 产品落地页（单页）
2. Privacy Policy 页面
3. Terms of Service 页面
4. 域名（建议 phantomknob.com 或 phantomknob.app）
5. 部署到 Vercel / Cloudflare Pages

### 1.7 DMG 安装器

1. 品牌化 DMG 背景图
2. 使用 create-dmg 自动化打包
3. 集成到 build_notarize.sh
4. DMG 签名和公证

---

## Phase 2：品质打磨（P1）

预计工期：4-6 周

### 2.1 崩溃上报

推荐 Sentry（免费层 5K events/月）。
1. SPM 集成 sentry-cocoa
2. 在 PhantomKnobApp init() 初始化
3. 添加 breadcrumbs 到关键状态转换
4. 设置中提供 opt-out 开关

### 2.2 日志系统清理

1. 引入 Apple os.log / Logger API
2. 定义日志分级：.debug / .info / .error
3. Release build 禁用 .debug
4. 删除 writeDebugLog 及所有调用点
5. 将 debug.log 加入 .gitignore

### 2.3 状态栏品牌图标

设计 4 种状态的 18×18pt template 图标（@1x / @2x），替换 SF Symbols。

### 2.4 Pro App 旋钮包

**第一批：**
- DaVinci Resolve（Color Wheels, 参数旋钮, 时间轴缩放）
- Final Cut Pro（色轮, 音量, 时间轴位置）
- Logic Pro（旋钮/推子, 效果器参数, Mixer）
- Adobe Premiere Pro（Lumetri 色轮, 音频混合器）
- Adobe After Effects（数值参数, 时间轴）

**架构变更：** bundled-rules 拆分为 base-rules.json（免费）和 pro-rules/（付费），RuleLibrary 按 LicenseState 加载。

### 2.5 引导体验英文适配

重写英文引导文案，添加手势动画说明，Step 3 App 列表动态化。

### 2.6 版本管理策略

SemVer，首发 1.0.0，创建 CHANGELOG.md，Build number 自增。

---

## Phase 3：增长功能（P2）

预计工期：6-8 周

### 3.1 Sparkle 自动更新

SPM 集成 Sparkle 2.x，EdDSA 签名，appcast.xml 托管，每 24 小时自动检查。

### 3.2 使用分析（Opt-in）

推荐 TelemetryDeck（隐私优先）。收集聚合事件：启动次数、旋钮使用时长、App 分布、模式分布、转化事件。首次启动 opt-in，设置中可关闭。

### 3.3 应用内反馈

菜单栏 "Send Feedback"，自动附带版本/系统信息。

### 3.4 营销素材

演示视频（30-60秒）、截图、GIF、产品文案。

### 3.5 Release Notes UI

更新后首次启动显示 "What's New" 窗口。

---

## Phase 4：规模化（未来）

### 4.1 iCloud 同步（重新启用已有 CloudSyncManager）
### 4.2 更多语言支持（日语 → 韩语 → 德/法 → 西班牙语）
### 4.3 性能优化（CPU < 0.1%, 内存 < 20MB, 事件延迟 < 5ms）
### 4.4 高级功能（外接触控板、多显示器、AppleScript 集成、规则社区）

---

## 技术债务清单

| 项目 | 严重度 | 说明 |
|---|---|---|
| 1.3GB debug.log | 🔴 高 | 立即删除并修复 writeDebugLog |
| ControlTarget 弃用 | 🟡 中 | 迁移到 DetectedTarget + InputTranslator |
| KnobStateManager 54KB | 🟡 中 | 拆分为子模块 |
| CustomizerHUDView 1071行 | 🟡 中 | 拆分为子组件 |
| README 空 | 🟢 低 | 补充说明 |

---

## 首发 Checklist

- [ ] Hardened Runtime 启用且所有功能正常
- [ ] Developer ID 签名 + Apple 公证通过
- [ ] 全新 macOS 上安装测试通过
- [ ] 英文 UI 全覆盖，无残留中文
- [ ] 14 天试用 → 免费层降级流程正常
- [ ] 许可证激活 / 恢复流程正常
- [ ] DMG 安装包品牌化
- [ ] 落地页上线且支付流程畅通
- [ ] Privacy Policy 已发布
- [ ] Sentry 崩溃上报已接入
- [ ] debug.log 问题已修复
- [ ] Pro App 旋钮包至少 3 个 App 适配完成
- [ ] App 图标和状态栏图标就位
- [ ] 所有现有测试通过
- [ ] 在 macOS 13 / 14 / 15 上分别测试

## Open Questions

1. **定价**：建议 $14.99-$19.99（一次性）
2. **域名**：是否已注册？
3. **Apple Developer 账号**：是否已有（$99/年）？
4. **Paddle 账号**：是否已注册？
5. **Pro 旋钮包 App 优先级**：除 DaVinci 外还有哪些？
6. **品牌命名**：PhantomKnob 是最终名称吗？
