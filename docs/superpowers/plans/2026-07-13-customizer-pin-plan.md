# 旋钮定制面板智能图钉 (Smart Pinning) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在旋钮定制面板顶栏添加“关闭”和“图钉”按钮，默认轻量级（点击外部或失焦自动隐藏），点击图钉激活钉住状态后，窗口始终置顶（.floating 层级）且屏蔽任何点击外部/失焦自动关闭的行为。

**架构：**
1. 在 `CustomizerHUDWindowController.swift` 中声明 `isPinned` 状态并在 didSet 中修改窗口 level (floating vs statusBar) 和 hidesOnDeactivate 行为。
2. 在 `CustomizerHUDWindowController.swift` 里的 `localClickMonitor`、`windowDidResignKey` 以及 `handleAppDeactivate` 逻辑中加入对 `isPinned` 的前置检查，当 pinned 为 true 时屏蔽 hide 退出逻辑。
3. 在 `CustomizerHUDView.swift` 顶栏 Header 重新规划 HStack，左侧保留 macOS 风格关闭按钮，右侧添加图钉按钮，绑定到 `CustomizerHUDWindowController.shared.isPinned`。

---

### 任务 1：升级 CustomizerHUDWindowController 支持 Pinned 状态控制与屏蔽过滤

**文件：**
- 修改：`PhantomKnob/Service/CustomizerHUDWindowController.swift`

- [ ] **步骤 1：增加 isPinned 属性及 level/behavior 动态同步**

在 `CustomizerHUDWindowController` 内定义 `isPinned` 变量：
```swift
    var isPinned: Bool = false {
        didSet {
            updateWindowLevelAndBehavior()
        }
    }
    
    private func updateWindowLevelAndBehavior() {
        guard let win = window else { return }
        if isPinned {
            win.level = .floating
            win.hidesOnDeactivate = false
        } else {
            win.level = .statusBar
            win.hidesOnDeactivate = true
        }
    }
```

- [ ] **步骤 2：重写 localClickMonitor 排除 Pinned 过滤**

在 `setupClickMonitor()` 监听闭包最开始，加入 `isPinned` 拦截检查：
```swift
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let win = self.window else { return event }
            
            // 如果被钉住，绝对不响应点击外部自动关闭
            if self.isPinned {
                return event
            }
            ...
```

- [ ] **步骤 3：重写 windowDidResignKey 排除 Pinned 过滤**

在 `windowDidResignKey(_:)` 方法最开始加入 `isPinned` 拦截检查：
```swift
    func windowDidResignKey(_ notification: Notification) {
        if isPinned {
            return
        }
        ...
```

- [ ] **步骤 4：重写 handleAppDeactivate 排除 Pinned 过滤**

在 `handleAppDeactivate()` 方法中过滤掉 Pinned 隐藏，仅隐藏 ColorPanel：
```swift
    @objc private func handleAppDeactivate() {
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.orderOut(nil)
        }
        if isPinned {
            return
        }
        hide()
    }
```

- [ ] **步骤 5：在 hide() 时将 isPinned 重置为 false**

在 `hide()` 执行时，将 `isPinned` 重设为 `false` 以确保下次弹出为默认的轻量级状态：
```swift
    func hide() {
        isPinned = false // 🌟 重置为默认轻量级
        window?.orderOut(nil)
        ...
```

- [ ] **步骤 6：运行 swift build 验证编译**

运行：`swift build` 在 `PhantomKnob` 路径下。
预期：编译成功，无任何语法错误。

- [ ] **步骤 7：Commit**

```bash
git add PhantomKnob/Service/CustomizerHUDWindowController.swift
git commit -m "feat: implement smart pinning state controller and ignore dismiss logic when pinned"
```

---

### 任务 2：重构 CustomizerHUDView 顶栏布局，添加关闭与图钉按钮

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：重构顶栏 Header 布局结构**

修改 `CustomizerHUDView.swift` 顶栏 Header HStack，将 metadata 显示居中，左侧放关闭按钮，右侧放图钉按钮：
```swift
    private var headerView: some View {
        HStack {
            // 左上角关闭按钮 (macOS 默认样式风格)
            Button(action: {
                CustomizerHUDWindowController.shared.hide()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 控件名称/角色信息
            VStack(spacing: 2) {
                Text(target.displayName.isEmpty ? String(localized: "hud.unknownTarget", defaultValue: "Unknown target") : target.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(target.axRole)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 右上角图钉按钮 (macOS 默认样式风格)
            Button(action: {
                CustomizerHUDWindowController.shared.isPinned.toggle()
            }) {
                Image(systemName: CustomizerHUDWindowController.shared.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CustomizerHUDWindowController.shared.isPinned ? .accentColor : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
```

- [ ] **步骤 2：运行 swift build 验证编译**

运行：`swift build`
预期：编译成功，无任何语法错误。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "feat: re-layout customizer top bar with close button and smart pin button"
```

---

### 任务 3：系统整体集成与功能测试

**文件：**
- 修改：`/Users/wb/.gemini/antigravity-ide/brain/5eadebab-19df-4d33-9374-34d87cbe072c/walkthrough.md`

- [ ] **步骤 1：整体编译项目**

运行：`swift build`
预期：Build complete! (0.00s)

- [ ] **步骤 2：测试默认轻量级交互**
   - 呼出真实 Overlay，按 C 键弹出面板。
   - 验证右上角为灰色空心图钉（未钉住）。
   - 点击面板外部空白区，验证面板立即隐退淡出。

- [ ] **步骤 3：测试钉住状态置顶与屏蔽交互**
   - 重新按 C 呼出面板，点击图钉图标，图钉变为蓝色实心 `pin.fill`。
   - 点击 Finder 窗口或其他第三方 App，验证面板不消失，且维持始终置顶。
   - 物理双指在触控板上打转，验证 Overlay 角度正常刷新，面板内容绝对不发生滚动。
   - 点击左上角 `xmark.circle.fill`，验证面板与真实 Overlay 同步隐退。
   - 重新呼出，验证面板状态已重置回轻量级（图钉为灰色未钉住）。

- [ ] **步骤 4：更新 walkthrough 归档并完成**

将测试结果和最终变化在 `walkthrough.md` 中进行补充总结，整理提交。
