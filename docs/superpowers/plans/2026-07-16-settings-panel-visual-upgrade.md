# 设置面板视觉风格与交互升级实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将设置面板重构成 560x440 大尺寸无边框毛玻璃面板，统一左上角关闭和右上角图钉交互，启用背景拖拽，卡片化设置模块并应用上下边缘淡出渐变遮罩。

**架构：**
- 修改 `SettingsWindowController` 增加 `win.isMovableByWindowBackground = true`、`isPinned` 状态及其与 `level`/`hidesOnDeactivate`/`localClickMonitor` 的联动控制。
- 修改 `SettingsView` 重构 `Header` 排布，给 `ScrollView` 添加上下边缘 Mask linear gradient 遮罩，并将 `GeneralSettingsView` 各区块重构为模块化半透卡片并加入 SF Symbols 视觉引导。

**技术栈：** SwiftUI, AppKit (NSWindow, NSVisualEffectView)

---

## 拟修改文件

- `[MODIFY] SettingsWindowController.swift` ([SettingsWindowController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/SettingsWindowController.swift))
- `[MODIFY] SettingsView.swift` ([SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift))

---

## 任务列表

### 任务 1：升级 `SettingsWindowController` 窗口行为

**文件：**
- 修改：`PhantomKnob/Service/SettingsWindowController.swift`

- [ ] **步骤 1：增加 `isPinned` 状态逻辑与窗口行为联动**
  在 `SettingsWindowController` 类中增加 `isPinned` 状态属性，并更新 `createWindow()` 方法：
  1. 窗口实例化后设置 `win.isMovableByWindowBackground = true`
  2. 增加 `updateWindowLevelAndBehavior()` 方法，在 `isPinned` 发生改变时，同步更新 `win.hidesOnDeactivate = !isPinned`
  3. 当 `isPinned` 为 `true` 时，移除 click monitor；否则启用 click monitor。
  4. 修改 `windowDidResignKey` 及 `localClickMonitor` 逻辑，在 `isPinned` 为 `true` 时不执行 `hide()`。

  修改实现如下：
  ```swift
  // line 21-45
  var isPinned: Bool = false {
      didSet {
          updateWindowLevelAndBehavior()
      }
  }
  
  private func updateWindowLevelAndBehavior() {
      guard let win = window else { return }
      if isPinned {
          win.hidesOnDeactivate = false
          removeClickMonitor()
      } else {
          win.hidesOnDeactivate = true
          setupClickMonitor()
      }
  }
  
  func show() {
      if window == nil {
          createWindow()
      }
      
      PKLogger.settings.info("Elevating activation policy to .regular to show settings window")
      NSApp.setActivationPolicy(.regular)
      
      window?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      
      // 激活初始图钉行为
      updateWindowLevelAndBehavior()
      
      NotificationCenter.default.post(name: NSNotification.Name("SettingsPanelDidShow"), object: nil)
  }
  ```
  在 `createWindow()` 内：
  ```swift
  // line 47-59
  let width: CGFloat = 560
  let height: CGFloat = 440
  // ...
  let win = SettingsWindow(
      contentRect: contentRect,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
  )
  win.isMovableByWindowBackground = true
  ```
  更新销毁/失焦检测：
  ```swift
  // windowDidResignKey
  func windowDidResignKey(_ notification: Notification) {
      if !isPinned {
          hide()
      }
  }
  
  // setupClickMonitor
  private func setupClickMonitor() {
      removeClickMonitor()
      localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
          guard let self = self, let win = self.window else { return event }
          if self.isPinned {
              return event
          }
          let clickLocation = NSEvent.mouseLocation
          let windowFrame = win.frame
          if !NSPointInRect(clickLocation, windowFrame) {
              DispatchQueue.main.async {
                  self.hide()
              }
          }
          return event
      }
  }
  ```

- [ ] **步骤 2：编译项目验证无语法错误**
  运行：`xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob clean build`
  预期：编译成功 (Build Succeeded)

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Service/SettingsWindowController.swift
  git commit -m "feat: upgrade SettingsWindowController size and drag/pin behavior"
  ```

---

### 任务 2：重构 `SettingsView` 窗口尺寸、顶栏及滚动掩膜

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：增加 `isPinned` 绑定并重构 Header 布局**
  1. 增加 `@State private var isPinned = false`，并在 `.onAppear` 中拉取 `SettingsWindowController.shared.isPinned` 进行同步。
  2. 重构顶栏排版为：左边 Close 圆形按钮，中间 Tabs，右边 Pin 圆形按钮。直接调用已有的 `HUDCircleButton` 组件。
  3. 将窗口底部限制修改为 `.frame(width: 560, height: 440)`。

- [ ] **步骤 2：对 ScrollView 应用上下边缘渐变淡出遮罩**
  1. 为 `ScrollView` 增加 `.mask` 剪切遮罩，利用 `LinearGradient` 让内容在靠近顶端 Divider 和底端边缘 5% 范围内（约 20px）柔和褪色，展现高级磨砂透出视感。
  2. 调整 ScrollView 内容的 `padding`，顶部 padding 大于等于 52pt 避开标题栏。

  重构后的 `SettingsView` 主体结构如下：
  ```swift
  struct SettingsView: View {
      @State private var activeTab: SettingsTab = .general
      @State private var isPinned: Bool = false
      
      var body: some View {
          VStack(spacing: 0) {
              // 顶栏：左侧关闭，中间切换，右侧图钉
              HStack {
                  HUDCircleButton(icon: "xmark", color: .white.opacity(0.7)) {
                      SettingsWindowController.shared.hide()
                  }
                  
                  Spacer()
                  
                  HStack(spacing: 8) {
                      Button(action: {
                          withAnimation(.easeInOut(duration: 0.15)) {
                              activeTab = .general
                          }
                      }) {
                          Text(String(localized: "settings.tab.general", defaultValue: "General"))
                              .font(.system(size: 13, weight: .medium))
                              .foregroundColor(activeTab == .general ? .white : .white.opacity(0.6))
                              .padding(.horizontal, 16)
                              .padding(.vertical, 6)
                              .background(activeTab == .general ? Color.white.opacity(0.12) : Color.clear)
                              .cornerRadius(8)
                      }
                      .buttonStyle(.plain)
                      
                      Button(action: {
                          withAnimation(.easeInOut(duration: 0.15)) {
                              activeTab = .about
                          }
                      }) {
                          Text(String(localized: "settings.tab.about", defaultValue: "About"))
                              .font(.system(size: 13, weight: .medium))
                              .foregroundColor(activeTab == .about ? .white : .white.opacity(0.6))
                              .padding(.horizontal, 16)
                              .padding(.vertical, 6)
                              .background(activeTab == .about ? Color.white.opacity(0.12) : Color.clear)
                              .cornerRadius(8)
                      }
                      .buttonStyle(.plain)
                  }
                  
                  Spacer()
                  
                  HUDCircleButton(
                      icon: isPinned ? "pin.fill" : "pin",
                      color: isPinned ? .orange : .white.opacity(0.6)
                  ) {
                      isPinned.toggle()
                      SettingsWindowController.shared.isPinned = isPinned
                  }
              }
              .padding(.horizontal, 20)
              .padding(.top, 16)
              .padding(.bottom, 12)
              
              Divider()
                  .background(Color.white.opacity(0.15))
              
              // 滚动主体
              ScrollView(showsIndicators: false) {
                  VStack(spacing: 16) {
                      if activeTab == .general {
                          GeneralSettingsView()
                      } else {
                          AboutView()
                      }
                  }
                  .padding(.horizontal, 20)
                  .padding(.top, 16)
                  .padding(.bottom, 24)
              }
              .frame(maxHeight: .infinity)
              .mask(
                  LinearGradient(
                      gradient: Gradient(stops: [
                          .init(color: .clear, location: 0.0),
                          .init(color: .black, location: 0.05),
                          .init(color: .black, location: 0.95),
                          .init(color: .clear, location: 1.0)
                      ]),
                      startPoint: .top,
                      endPoint: .bottom
                  )
              )
          }
          .frame(width: 560, height: 440)
          .foregroundColor(.white)
          .onAppear {
              isPinned = SettingsWindowController.shared.isPinned
          }
      }
  }
  ```

- [ ] **步骤 3：编译验证**
  运行编译确认没有报错。

---

### 任务 3：重构 `GeneralSettingsView` 设置卡片化并引入 SF Icons

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：重写各个设置区域为精致磨砂卡片且增设 SF Icons**
  把 `GeneralSettingsView` 内的 6 个部分均改造成卡片化，带圆角 `12`、细边框 `white.opacity(0.06)`、半透明白底 `white.opacity(0.04)`。
  1. **快捷键卡片**（图标 `keyboard`，主题蓝）
  2. **系统辅助功能卡片**：
     - 使用 `checkmark.shield`（已授权）或 `hand.raised.badge.ellipsis`（未授权）。
     - 若未授权，背景设为 `Color.red.opacity(0.03)`，边框设为 `Color.red.opacity(0.2)`，以红/橙卡片高亮；已授权设为绿/常规色。
  3. **自启动与更新卡片**（图标 `bolt.horizontal`）：
     - 将开机自启、启动显示指南、自动检查更新合并入内。
  4. **界面显示语言卡片**（图标 `globe`，主题蓝）
  5. **触控板状态诊断卡片**（图标 `hand.draw`）：
     - 检测状态拉取 `UserDefaults.app.bool(forKey: "userGuideTouchpadPracticed")`。
     - 若为 `true`：显示硬件状态“已成功检测 MacBook 触控板并验证通过”；
     - 若为 `false`：提示未验证，提供点击重试引导。
     - 并在 `resetAndRedetect()` 内将 `userGuideTouchpadPracticed` 和 `com.phantomknob.detectionResult` 一并清空。
  6. **隐私数据卡片**（图标 `lock.shield`）

- [ ] **步骤 2：编译项目并运行测试**
  运行单元测试确认无影响：
  `xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob`

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/View/SettingsView.swift
  git commit -m "feat: refactor GeneralSettingsView to card grid layout with SF Symbols and diagnostic statuses"
  ```

---

## 验证计划

### 自动化测试
运行以下命令：
- 编译整个项目：`xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob clean build`
- 运行测试集：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob`

### 手动验证
1. 打开 PhantomKnob 设置面板，确认尺寸明显放大（`560x440`），页面清爽。
2. 拖拽空白磨砂背景区，确认窗口可平顺拖拽。
3. 检查顶栏交互：点击左上角关闭，窗口正确收起；点击右上角图钉，确认开启置顶，点击外部不隐藏。
4. 滚动设置内容，验证卡片上边缘与下边缘在接近边界时呈渐变半透明模糊退色。
5. 检查卡片图标与指示色，确认辅助功能已授权和未授权时的卡片高亮与提示正确。
6. 点击“重新检测触控板”，确认新手引导正确弹出且设置项数据清除成功。
