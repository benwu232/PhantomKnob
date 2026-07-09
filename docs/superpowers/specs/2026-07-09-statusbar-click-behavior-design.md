# 状态栏图标点击响应行为设计规格

本规格说明书定义了 PhantomKnob macOS 应用状态栏图标（Status Bar Icon）鼠标点击响应行为的修改方案。

## 1. 目标 (Goal)

优化状态栏图标的点击交互，支持以下交互逻辑：
- **鼠标左键单击**：切换 Knob 的全局控制状态（`inactive` / `activated`）。
- **鼠标右键单击**（或 **Control + 左键单击**）：弹出状态栏主菜单（Menu）。
- **鼠标左键双击**：显示/隐藏手势旋钮面板（Knob Panel Window）。

---

## 2. 交互逻辑与防抖设计 (Interaction & Debounce Logic)

由于“左键双击”必定会先触发一次“左键单击”，为了避免双击时误触发状态切换，必须引入基于 macOS 系统双击间隔时间的延迟防抖机制。

### 2.1 延迟判定规则

- 当触发**左键单击**（`clickCount == 1`）时：
  1. 取消任何已安排但尚未执行的点击动作。
  2. 获取当前用户的系统双击间隔时间 `NSEvent.doubleClickInterval`。
  3. 安排一个延迟任务，在 `doubleClickInterval` 秒后执行 Knob 状态的切换操作（调用 `toggleMode()`）。
- 当触发**左键双击**（`clickCount == 2`）时：
  1. 立即取消上述 pending 的延迟任务。
  2. 立即执行“显示/隐藏旋钮面板”操作（调用 `KnobPanelWindowController.shared.toggle()`）。
- 当触发**右键单击**（`rightMouseUp` 或 `Control + leftMouseUp`）时：
  1. 立即取消任何 pending 的左键延迟任务。
  2. 立即弹出主菜单（调用 `statusItem.popUpMenu(_:)`）。

---

## 3. 技术实现方案 (Technical Implementation)

### 3.1 状态栏按钮事件配置

修改 `StatusBarController.swift` 中的 `setupStatusBar()`：
```swift
private func setupStatusBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    if let button = statusItem?.button {
        button.action = #selector(statusBarButtonClicked)
        button.target = self
        // 显式允许接收左键和右键的 MouseUp 事件
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    setupMenu()
    updateState(.inactive)
}
```

### 3.2 事件分发核心逻辑

在 `StatusBarController.swift` 中更新 `handleStatusItemClick(event:)`：
```swift
func handleStatusItemClick(event: NSEvent?) {
    guard let ev = event else {
        if let menu = menu {
            statusItem?.popUpMenu(menu)
        }
        return
    }
    
    // 判断是否为右键点击事件
    let isRightClick = ev.type == .rightMouseUp || 
                       (ev.type == .leftMouseUp && ev.modifierFlags.contains(.control))
    
    if isRightClick {
        pendingMenuWorkItem?.cancel()
        pendingMenuWorkItem = nil
        if let menu = menu {
            statusItem?.popUpMenu(menu)
        }
        return
    }
    
    // 左键点击判定
    if ev.clickCount == 2 {
        pendingMenuWorkItem?.cancel()
        pendingMenuWorkItem = nil
        KnobPanelWindowController.shared.toggle()
    } else if ev.clickCount == 1 {
        pendingMenuWorkItem?.cancel()
        
        let interval = NSEvent.doubleClickInterval
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.toggleMode()
            self.pendingMenuWorkItem = nil
        }
        pendingMenuWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
    }
}
```

---

## 4. 测试与验证计划 (Test & Verification Plan)

### 4.1 单元测试用例

在 `StatusBarControllerTests.swift` 中更新并新增测试用例：
- `testStatusBarDoubleCickTogglesPanel()`: 模拟左键双击事件，验证 `KnobPanelWindowController` 的可见性发生变化。
- `testStatusBarLeftSingleClickTogglesModeAfterInterval()`: 模拟左键单击事件，验证在延迟 `doubleClickInterval` 秒后，能够正确触发状态切换。
- `testStatusBarRightClickShowsMenu()`: 模拟右键单击事件，验证立即取消 pending 的任务并尝试拉起菜单。

### 4.2 手动测试

- 运行 App，多次执行左键单击，确认可以灵敏切换激活/未激活状态。
- 右键点击状态栏图标，确认可以弹出菜单。
- 双击状态栏图标，确认能显示面板，且过程中不会错误切换 Knob 状态。
