# 交互式使用引导与 Onboarding 流程重塑设计方案

本文档详述了将 Phantom Knob 转为纯菜单栏（Menu Bar only）常驻工具的设计，包括删除冗余主窗口、将“触控板绝对坐标检测”整合进新手引导（UserGuide），并重构新手引导以展示多旋钮对比、键盘倍率微调和按 `C` 键定制功能。

---

## 1. 业务目标与用户体验 (Goals & UX)

* **零干扰常驻体验**：应用启动后不显示 Dock 图标，不弹出默认的空白主窗口。
* **首次引导 (Onboarding) 体验**：
  * **第一步：设备检测与简单旋钮**。用户被引导将鼠标悬停到自绘音量旋钮上，并在触控板双指旋转。后台监测多点绝对坐标 (`normalizedPosition`)。捕获到 3 个样本后，打勾并提示“✅ 触控板检测成功！您的设备完美支持。”，解锁下一步。
  * **第二步：两种旋钮对比与深度定制**。面板尺寸调高至宽度 580，高度 460，给排版留出充裕空间。并排展示**双环旋钮**与**无级变速旋钮**，其外观直接复用应用中已实现的 `OverlayView` 刻度线风格：
    - **旋钮上方**：实时显示当前数值（0-100，保留一位小数，例如：`双环旋钮: 50.0`）。
    - **旋钮正中心**：显示合成后的当前倍率（例如：`1.0x`）。
    - **双环旋钮**：外环倍率为 `1.0`，内环倍率为 `0.1`，根据手势旋转的实时半径进行档位切换，并在圆心变化显示。
    - **无级变速旋钮**：变速倍率在 `0.1` 至 `5.0` 之间随两指旋转半径进行线性插值，并在圆心实时显示该倍数。
    - 旋转期间，配合键盘 `↑`/`↓`（±1.0x）和 `←`/`→`（±0.1x）以及数字键 `2-9` 还能进行灵敏度倍率微调，并参与中心数值的乘法合成。
    - 练习时可按 **`C`** 键（或点击按钮），在当前位置呼出应用内置的 **「旋钮定制面板」**，进行参数微调（非强制引导）。
  * **第三步：开始全局控制**。介绍全局激活热键 `⌘⌥R` 和 `Option` 键临时暂停，提供“下次启动不再显示”开关，关闭退出。

---

## 2. 技术架构与组件设计 (System Architecture)

### 2.1 纯菜单栏 App 配置与启动重构
* **LSUIElement**：在 `project.yml` 中配置 `LSUIElement: true`。重新运行 `xcodegen generate` 写入 Info.plist。
* **PhantomKnobApp.swift**：
  - 移除 `WindowGroup` 场景，App 仅包含 `Settings { SettingsView() }` 场景。
  - 将手势监听的启动 (`knobStateManager.start()`) 和使用引导是否弹窗检查移至 `AppState` 的 `init()` 方法中执行。
* **物理删除废弃文件**：
  - `WelcomeView.swift`, `DetectionView.swift`, `ResultView.swift`, `DemoView.swift`
  - `AppViewModel.swift`, `DetectionViewModel.swift`, `DetectionCache.swift`

### 2.2 使用引导 (UserGuideView & UserGuideViewModel) 重构
我们将在 `UserGuideViewModel` 中新增状态属性并监听事件：
* `currentStep` 字段控制 3 步页面跳转。
* `isTouchpadSupported` 表示触控板检测状态（初始化为 `false`，后台捕获成功后置为 `true`）。
* `doubleKnobVal` (0-100) 和 `linearKnobVal` (0-100) 用于 Step 2 中的并排旋钮数值。
* `currentHoveredType` 标记鼠标当前悬停的虚拟练习控件（`.step1Volume`, `.step2Double`, `.step2Linear`, `.sliderTest`），方便将触控板旋转 deltas 路由到不同的值上。
* **键盘事件侦听**：在 Step 2 练习中，若有手势被拦截，事件 tap 允许捕获 arrow keys/number keys 并即时作用于 `lastResolvedBaseScale`，在 UI 顶端更新灵敏度值。
* **唤起 Customizer HUD**：当用户在悬浮在练习控件上并按下 `C` 键时，触发 `enterCustomization()`，将 `CustomizerHUDWindowController.shared.show(for: target)` 弹出在当前位置上层。

---

## 3. 验证计划 (Verification Plan)

### 3.1 自动化测试
* 运行 `xcodegen generate` 重新生成项目。
* 执行 `xcodebuild test`，验证所有单元测试是否成功编译并全部通过。

### 3.2 手动验证
1. 启动项目，验证 Dock 栏中**不显示**应用图标，且没有打开任何默认的空白窗口。
2. 首次运行弹出的 `UserGuide` 窗口：
   - 验证 Step 1 触控板检测，双指在音量旋钮上旋转后，是否正确提示“检测成功”并解锁下一步。
   - 验证 Step 2 并排显示双环旋钮和无级变速旋钮，使用 `OverlayView` 外观，上方显示数值，中心显示当前倍数，且旋转时倍数根据双指间距改变。
   - 验证在 Step 2 旋转时，按下键盘方向键是否能在 UI 上即时看到倍率变化；按下 `C` 键是否能正确弹出定制面板。
   - 验证 Step 3 选择不再显示并点击“开启体验”后，窗口顺利关闭，状态栏常驻。
