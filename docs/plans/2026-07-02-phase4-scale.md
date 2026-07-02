# Phase 4：规模化 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。

**目标：** 在获得市场验证后推进规模化功能——iCloud 同步、多语言、性能优化、高级功能。

**前置依赖：** Phase 1-3 完成 + 用户反馈数据

---

## 任务 1：iCloud 同步（重新启用）

**文件：**
- 修改：`PhantomKnob/Service/CloudSyncManager.swift`（已有，被禁用）
- 修改：`PhantomKnob/PhantomKnob.entitlements`
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`
- 创建：`PhantomKnobTests/CloudSyncIntegrationTests.swift`

- [ ] **步骤 1：诊断原始禁用原因**

查看 commit `3addf18` ("disable iCloud KVS sync") 的 commit message 和 diff，理解禁用原因。

```bash
git show 3addf18
```

- [ ] **步骤 2：重新启用 iCloud KVS entitlement**

```xml
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)com.phantomknob.PhantomKnob</string>
```

- [ ] **步骤 3：修改 CloudSyncManager 添加 FeatureGate 检查**

```swift
func start() {
    guard FeatureGate.current.isUnlocked(.iCloudSync) else {
        NSLog("[CloudSyncManager] iCloud sync is a premium feature, skipping")
        return
    }
    // ... 现有启动逻辑 ...
}
```

- [ ] **步骤 4：实现冲突解决策略**

```swift
// Last-write-wins 策略，基于时间戳
func resolveConflict(local: ControlRule, remote: ControlRule) -> ControlRule {
    // 比较 lastModified 时间戳，取较新的
    return local.lastModified > remote.lastModified ? local : remote
}
```

- [ ] **步骤 5：在 AppState.init() 中取消注释**

```swift
// 替换：
// CloudSyncManager.shared.start()
// 为：
CloudSyncManager.shared.start()
```

- [ ] **步骤 6：添加集成测试**
- [ ] **步骤 7：在两台 Mac 上端到端验证同步**
- [ ] **步骤 8：Commit**

```bash
git commit -m "feat: re-enable iCloud KVS sync for premium users with conflict resolution"
```

---

## 任务 2：多语言支持

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：添加日语翻译（ja）**

第一优先级。macOS 工具在日本市场有需求。

- 聘请专业日语翻译或使用高质量翻译服务
- 特别注意 UI 术语的本地化（"旋钮" → ノブ/ダイヤル）
- 验证日语环境下的 UI 布局（日文字符宽度不同）

- [ ] **步骤 2：添加韩语翻译（ko）**
- [ ] **步骤 3：添加德语翻译（de）**
- [ ] **步骤 4：添加法语翻译（fr）**
- [ ] **步骤 5：添加西班牙语翻译（es）**

- [ ] **步骤 6：验证所有语言的 UI 布局**

在每种语言下运行 App，检查文本截断、布局溢出、换行问题。

- [ ] **步骤 7：Commit**

```bash
git commit -m "i18n: add Japanese, Korean, German, French, Spanish translations"
```

---

## 任务 3：性能优化

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/Service/MultitouchManager.swift`

- [ ] **步骤 1：CPU 审计**

使用 Instruments (Time Profiler) 分析后台常驻时的 CPU 使用：
- 目标：idle 状态 < 0.1% CPU
- 检查 Timer 是否在不需要时仍在运行
- 检查 NSEvent monitor 是否有不必要的开销

- [ ] **步骤 2：内存审计**

使用 Instruments (Allocations) 分析内存使用：
- 目标：< 20MB 常驻内存
- 检查 Overlay window 的内存泄漏
- 检查 Combine subscription 的清理

- [ ] **步骤 3：事件延迟测量**

在 MultitouchManager 中添加性能计数器：
```swift
let start = CACurrentMediaTime()
// ... 处理触控事件 ...
let elapsed = CACurrentMediaTime() - start
if elapsed > 0.005 { // > 5ms
    Logger.knob.warning("Touch event processing took \(elapsed * 1000, format: .fixed(precision: 1))ms")
}
```

- [ ] **步骤 4：电池影响测试**

运行 App 2 小时，检查 Activity Monitor 中是否出现 "高能耗" 标记。

- [ ] **步骤 5：优化发现的瓶颈**
- [ ] **步骤 6：Commit**

```bash
git commit -m "perf: optimize CPU, memory, and event processing latency"
```

---

## 任务 4：高级功能（根据用户反馈优先级排序）

### 4a：外接触控板支持

- [ ] **步骤 1：调研 MultitouchManager 对外接触控板的兼容性**
- [ ] **步骤 2：添加设备标识区分（内置 vs 外接）**
- [ ] **步骤 3：测试 Apple Magic Trackpad 2**
- [ ] **步骤 4：Commit**

### 4b：多显示器 Overlay 定位

- [ ] **步骤 1：修改 OverlayController.show() 支持多显示器**

```swift
// 已有基础逻辑，需验证：
let activeScreen = NSScreen.screens.first { $0.frame.contains(position) } ?? NSScreen.main
```

- [ ] **步骤 2：测试 2-3 个显示器配置**
- [ ] **步骤 3：Commit**

### 4c：规则导出/导入/分享

- [ ] **步骤 1：添加规则导出功能（JSON 文件）**

```swift
func exportRules(to url: URL) throws {
    let data = try JSONEncoder().encode(rules)
    try data.write(to: url)
}
```

- [ ] **步骤 2：添加规则导入功能**

```swift
func importRules(from url: URL) throws {
    let data = try Data(contentsOf: url)
    let imported = try JSONDecoder().decode([ControlRule].self, from: data)
    rules.append(contentsOf: imported)
    save()
}
```

- [ ] **步骤 3：在设置或菜单中添加 Export/Import 入口**
- [ ] **步骤 4：仅限 Licensed 用户（FeatureGate 检查）**
- [ ] **步骤 5：Commit**

```bash
git commit -m "feat: add rule export/import for premium users"
```

### 4d：AppleScript / Shortcuts 集成

- [ ] **步骤 1：添加 NSAppleScript 支持**

允许用户通过 AppleScript 控制 PhantomKnob：
```applescript
tell application "PhantomKnob"
    activate knob mode
    deactivate knob mode
end tell
```

- [ ] **步骤 2：添加 Shortcuts action**

使用 App Intents framework 暴露 Shortcuts 动作。

- [ ] **步骤 3：Commit**

```bash
git commit -m "feat: add AppleScript and Shortcuts integration"
```

---

## 任务 5：技术债务清理

- [ ] **步骤 1：拆分 KnobStateManager（54KB）**

```
KnobStateManager.swift (核心状态机 + 协调)
├── GestureProcessor.swift (手势处理逻辑)
├── TargetManager.swift (目标管理)
└── SessionManager.swift (会话计时、激活延迟)
```

- [ ] **步骤 2：拆分 CustomizerHUDView（1071 行）**

```
CustomizerHUDView.swift (主容器)
├── ConflictResolutionView.swift
├── SingleKnobConfigView.swift
├── DoubleKnobConfigView.swift
└── LinearKnobConfigView.swift
```

- [ ] **步骤 3：完成 ControlTarget 弃用迁移**

移除 DemoSliderTarget 和 GenericControlTarget 中的遗留代码。

- [ ] **步骤 4：更新 README.md**

添加项目描述、截图、安装说明、开发指南。

- [ ] **步骤 5：Commit**

```bash
git commit -m "refactor: split large files and clean up technical debt"
```

---

## 验证计划

### 自动化测试
```bash
xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnobTests
```

### 手动验证
1. **iCloud**：在两台 Mac 上创建规则，确认同步正常
2. **多语言**：每种语言下完整走一遍 App 流程
3. **性能**：Instruments 确认 CPU < 0.1%, 内存 < 20MB
4. **外接触控板**：Magic Trackpad 2 测试
5. **规则导出**：导出 → 导入 → 验证规则正确
