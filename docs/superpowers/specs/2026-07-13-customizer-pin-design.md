# 旋钮定制面板智能图钉（Smart Pinning）设计规范

## 1. 业务目标
为了在用户进行“边调边试”测试时提供最好的连贯体验，允许用户通过点击面板右上角的图钉（Pin）按钮将定制面板钉住：
- 钉住后，面板窗口置顶，且不会因为用户点击主应用或其他地方导致面板隐退。
- 用户可以点击主应用的各个参数或操作触控板手势，实时看见效果。
- 缺省为轻量级状态（Unpinned），此时点击外部或失焦依然会自动隐退。

---

## 2. 界面设计 (UI/UX)
- **关闭按钮**：位于顶栏左上角，使用 macOS 原生图标 `xmark.circle.fill`，在 Hover 时高亮，点击立即显式关闭面板（并恢复状态机）。
- **图钉按钮**：位于顶栏右上角，使用 macOS 系统标准图钉图标：
  - **未钉住 (Unpinned, 缺省)**：使用 `pin` 图标。
  - **钉住 (Pinned)**：使用 `pin.fill` 图标（使用系统主题蓝色或高亮高清晰度显示）。
- **按钮样式**：使用 macOS 标准微动图标，采用标准的点击回弹。

---

## 3. 详细设计 (Detailed Design)

### 3.1 CustomizerHUDWindowController.swift 状态控制
- 增加 `var isPinned: Bool = false` 属性。
- 并在变更时修改 `CustomizerWindow` 的行为：
  ```swift
  var isPinned: Bool = false {
      didSet {
          updateWindowLevelAndBehavior()
      }
  }
  
  private func updateWindowLevelAndBehavior() {
      guard let win = window else { return }
      if isPinned {
          win.level = .floating         // 始终浮在最上层
          win.hidesOnDeactivate = false // 屏蔽 App 失去前台后的系统级窗口隐藏
      } else {
          win.level = .statusBar
          win.hidesOnDeactivate = true
      }
  }
  ```
- **避让/关闭行为过滤**：
  - 在 `localClickMonitor` 监听到点击外部时，如果 `isPinned == true`，直接返回，不调用 `hide()`。
  - 在 `windowDidResignKey`（窗口失焦）被触发时，如果 `isPinned == true`，直接返回，不调用 `hide()`。
  - 在 `handleAppDeactivate`（App 失去前台）触发时，如果 `isPinned == true`，不调用 `hide()`（但仍正常调用 `NSColorPanel.shared.orderOut(nil)` 收起系统调色板）。

### 3.2 CustomizerHUDView.swift 顶栏布局
- 顶栏左右边缘排布：
  - 左侧：关闭按钮 `xmark.circle.fill`。
  - 右侧：图钉按钮（绑定共享的 `isPinned` 状态）。
- 声明共享的 `@State` 或 `@Binding` 属性绑定到 `CustomizerHUDWindowController.shared.isPinned`。
- 图钉点击时：
  ```swift
  Button(action: {
      CustomizerHUDWindowController.shared.isPinned.toggle()
  }) {
      Image(systemName: CustomizerHUDWindowController.shared.isPinned ? "pin.fill" : "pin")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(CustomizerHUDWindowController.shared.isPinned ? .accentColor : .gray)
  }
  .buttonStyle(.plain)
  ```

---

## 4. 验证计划

### 4.1 手工联调测试
1. 呼出真实 Overlay，按 C 键弹出定制面板。
2. 验证定制面板右上角存在 `pin` 形状图钉按钮（默认未填充灰色）。
3. 验证点击定制面板外的 Finder 窗口或空白，定制面板自动隐退。
4. 重新弹出，点击图钉使其变为蓝色高亮 `pin.fill`：
   - 验证点击第三方应用或 Finder，定制面板保持显示，始终置顶在最上方。
   - 在主应用中操作物理手势，验证 Overlay 正常，且定制面板完好可见且其 ScrollView 绝不发生滚动。
5. 点击定制面板右上角的图钉（解开）：
   - 验证图钉恢复为未填充灰色，且点击外部空白，面板立刻顺畅隐退。
