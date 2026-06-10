# User Guide (使用引导) 设计规格说明书

本篇文档详述了 Phantom Knob 中独立的使用引导（User Guide）窗口及其手势练习、物理 Tick 音效反馈、系统音量同步调节及首次运行逻辑的设计规格。

---

## 1. 业务目标与用户体验 (Goals & UX Flow)

* **首次运行激活**：
  * 应用第一次启动时，检查 `UserDefaults`。若用户尚未完成使用引导，则**自动弹出独立的使用引导（User Guide）窗口**，而非 KnobPanel。
* **常驻主菜单入口**：
  * 在状态栏下拉菜单中新增 **“使用引导...” (User Guide...)** 菜单项，用户可随时点击重新唤起练习。
* **新手引导三步流**：
  1. **第一步（Welcome）**：欢迎使用 PhantomKnob，简述双指触控板旋转的基本手势操作，点击“开始练习”进入下一步。
  2. **第二步（Practice）**：
     * **鼠标悬浮判定**：当鼠标不在旋钮圆盘上时，圆盘展示呼吸发光与手指浮动旋转的指引动画，提示：“请将光标移动到音量旋钮上”。当鼠标悬停于旋钮上，圆盘平滑放大 1.15 倍并隐藏指引动画，提示文案变为：“非常好！现在请在触控板上放置双指，开始旋转以调整系统音量”。
     * **旋转练习与音量同步**：用户放置双指旋转，旋钮同步转动。系统音量真实递增/递减（调用 `AudioControlService`），提供系统级 HUD 视听联动。
     * **1° 清脆嘀嗒反馈音**：手势每累积旋转 1.0°，通过 macOS 底层音效播放一声极清脆的 Tick 音（滴答声），模拟真实硬件旋钮的段落感。
     * **100° 目标限制**：进度条展示旋转进度（0° 到 100°）。当旋转累计满 100° 时，解锁“下一步”按钮。
  3. **第三步（Success）**：恭喜用户通关。
     * **系统与手势机制教学**：告诉用户他们可以通过快捷键 `⌘⌥R`（或状态栏菜单的“切换控制模式”）激活/关闭全局旋钮控制模式。激活后，将鼠标悬停在其他应用的滑块/滚动条上，即可使用双指旋转进行手势调节。
     * **应用适配提示与列表**：明确告知用户，经过适配的应用程序才能获得完美平滑的旋转控制体验。给出当前支持的适配应用列表：**CapCut (剪映)**、**QuickTime Player** 等。
     * **点击开启**：点击“开启”将写入 `firstRunUserGuideCompleted = true`，关闭引导窗口，并自动弹出 `KnobPanel` 控制面板。

---

## 2. 技术架构与组件设计 (System Architecture)

### 2.1 引导窗口控制器 (`UserGuideWindowController`)
* 管理一个无边框（`borderless`）的 `NSPanel`（尺寸固定为 `560x400`，居中显示）。
* 底层嵌入 `NSVisualEffectView`（材质为 `.hudWindow`，`20pt` 圆角），呈现 Glassmorphism 毛玻璃效果。
* `canBecomeKey` 返回 `true` 以便正确拦截 `Esc` 键用于关闭窗口。
* 具备点击外部以及失去焦点自动淡出关闭的机制（同 `KnobPanelWindowController` 逻辑）。

### 2.2 引导视图模型与嘀嗒声计算 (`UserGuideViewModel`)
* **嘀嗒声累加器**：
  * 声明 `private var tickAccumulator: Double = 0.0`。
  * 每次接收到通知中心的 `KnobPanelDidRotate` 角度 delta：
    ```swift
    tickAccumulator += abs(delta)
    if tickAccumulator >= 1.0 {
        let ticks = Int(tickAccumulator)
        for _ in 0..<ticks {
            // 系统内置极清脆 Tick 滴答音效 ID 1104 / 1057
            AudioServicesPlaySystemSound(1104)
        }
        tickAccumulator -= Double(ticks)
    }
    ```
* **系统音量调节**：
  * 在 Step 2 中，利用 `AudioControlService` 实时设置当前音量。

### 2.3 状态机手势捕获与路由
* 在 [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift) 的 `onMultitouchBegan` 手势捕获开始处，增加对 `UserGuideWindowController` 可见性的检查：
  `if KnobPanelWindowController.shared.isVisible || UserGuideWindowController.shared.isVisible`
* 手势被 `ControlPanel` target 逻辑路由，在 `onMultitouchMoved` 中发布 `KnobPanelDidRotate` 通知广播度数，`UserGuideViewModel` 监听该通知即可。

---

## 3. 测试与验证计划 (Testing & Verification)

* **单元测试**：
  * 编写 `UserGuideViewModelTests`，测试 `currentStep` 流转、`tickAccumulator` 在 1.0° 时的累加与扣减，以及累计旋转 100° 时解锁 `isStep2Unlocked` 的判定逻辑。
* **手动验证**：
  * 清除 `UserDefaults` 后冷启动 App，确认弹出的是引导窗口而非控制面板。
  * 移动鼠标进入/离开虚拟音量旋钮，检查手指旋转动画与文案提示的平滑切换。
  * 进行手势旋转，确保听到连续清脆的嘀嗒声、系统音量 HUD 在桌面上出现并发生变化，且进度条前进，满 100° 后解锁下一步。
  * 通关后关闭引导窗口，确认立刻弹出 KnobPanel 且后续启动不再加载引导窗口。
