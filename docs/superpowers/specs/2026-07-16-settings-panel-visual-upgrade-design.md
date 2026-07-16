# 设置面板视觉风格与交互升级设计规范 (Settings Panel Visual & Interaction Upgrade)

本文档规范了 PhantomKnob 设置面板（Settings Panel）的视觉重构与交互功能升级。此次升级旨在使设置面板的风格与快捷面板（KnobPanelView）、旋钮定制面板（CustomizerHUDView）高度统一，并引入多项提升 macOS 原生高级质感的微交互。

## 1. 升级目标 (Goals)

1. **尺寸优化**：将窗口默认大小从 `480 * 360` 提升至 `560 * 440`，拓宽版面，解决设置项拥挤问题。
2. **背景拖拽移动**：开启 `win.isMovableByWindowBackground = true`，使无边框设置面板的任意空白磨砂背景皆可拖动，提升操作自由度。
3. **交互规范统一**：
   - 左上角增加圆形关闭按钮，右上角增加圆形图钉（Pin）按钮。
   - 实现图钉与悬浮置顶/自动隐藏的状态联动，未图钉时失焦或点击外部隐藏，图钉后持久保持在前台。
4. **磨砂玻璃滚动遮罩**：使用 ZStack 和 LinearGradient 对滚动区域上下边缘进行渐变遮罩，使设置卡片在滚动时以半透状态淡入/淡出标题栏和下边缘。
5. **卡片模块化与 SF Icons 引入**：
   - 将原散落各处的设置组件整编为 6 个半透磨砂卡片容器。
   - 每个卡片标题增加相关的 SF 符号指引。
   - 在大尺寸下对部分设置行进行更紧凑的双列混排。

---

## 2. 详细设计 (Detailed Design)

### 2.1 窗口与控制器 (`SettingsWindowController`)
* **修改点 1**：在创建 `SettingsWindow` 时，设置 `win.isMovableByWindowBackground = true`。
* **修改点 2**：引入 `isPinned: Bool` 状态，默认 `false`。
* **修改点 3**：联动图钉行为：
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
          removeClickMonitor()
      } else {
          win.level = .floating // 仍保持在普通浮动层
          win.hidesOnDeactivate = true
          setupClickMonitor()
      }
  }
  ```
* **修改点 4**：在 `windowDidResignKey` 与 `localClickMonitor` 触发时，若 `isPinned` 为 `true`，则直接忽略，不执行隐藏。

### 2.2 界面排版 (`SettingsView`)
`SettingsView` 将使用 `ZStack` 实现上下遮罩：
* 顶层放置毛玻璃标题栏（`SettingsHeaderView`），高度约为 `52pt`。
* 底层为 `ScrollView`，其内部卡片包含：
  1. **快捷键设置卡片**：SF 符号 `keyboard`，全局开关热键录制。
  2. **系统辅助功能卡片**：SF 符号 `hand.raised.badge.ellipsis` / `checkmark.shield`。未授权时呈现警告红边框与淡红背景（`red.opacity(0.04)`），授权后为绿边框。
  3. **启动与更新卡片**：SF 符号 `bolt.horizontal`。将“开机登录自启”、“显示用户指南”、“自动检查更新”合并到该卡片，大窗口下双列排列以精简纵向空间。
  4. **界面语言设置卡片**：SF 符号 `globe`，水平混排放置 Picker 下拉菜单。
  5. **触控板状态诊断卡片**：SF 符号 `hand.draw`，展示当前已测出的硬件名称和支持提示，右侧为重测按钮。
  6. **隐私数据设置卡片**：SF 符号 `lock.shield`，放置发送崩溃日志和匿名统计复选框。

* **磨砂玻璃边缘渐变暗示**：
  对 `ScrollView` 里的内容应用 SwiftUI 渐变 Mask：
  ```swift
  .mask(
      LinearGradient(
          gradient: Gradient(stops: [
              .init(color: .clear, location: 0.0),
              .init(color: .black, location: 0.08),
              .init(color: .black, location: 0.92),
              .init(color: .clear, location: 1.0)
          ]),
          startPoint: .top,
          endPoint: .bottom
      )
  )
  ```
  在滚动内容上下增加 padding 确保默认显示完全（头部 padding 大于等于 52pt 避开标题栏）。

---

## 3. 验证计划 (Verification Plan)

### 3.1 手动验证
1. **尺寸与移动**：打开设置面板，验证窗口是否为更大尺寸；拖拽面板的非按钮空白处，验证面板是否可以平滑移动。
2. **关闭与图钉**：
   - 点击左上角关闭按钮，验证面板是否顺利隐藏。
   - 切换图钉状态。未打图钉时，点击设置面板以外的屏幕任意区域，验证面板是否自动收起。
   - 开启图钉后，点击外部或操作其他 App 窗口，验证设置面板是否稳稳保持置顶显示。
3. **滚动淡入淡出遮罩**：上下拖动设置项，仔细观察边缘，验证顶端和底端的设置项在滑过边界时，是否柔和地渐变隐入标题栏毛玻璃下方。
4. **卡片布局与 SF 图标**：确认 General 和 About 分页中的六大卡片排版整齐，所有 SF 图标加载正确。
