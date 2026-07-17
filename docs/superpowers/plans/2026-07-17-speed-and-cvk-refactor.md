# Speed Naming & CVK Refactor 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 sensitivity 统一重命名为 knobSpeed，移除废弃的 SensitivityConfig，重命名 ControlRule.swift 为 KnobConfig.swift，并将 linear 旋钮更名为 cvk 旋钮，完成全面的命名精简。

**架构：**
1. 重命名物理文件 `ControlRule.swift` -> `KnobConfig.swift`、`ControlTests.swift` -> `DemoSliderTargetTests.swift`，删除 `SensitivityConfig`，同步修改项目文件 `.pbxproj`；
2. 在核心计算逻辑及各 ViewModel 中重命名 `sensitivity` -> `knobSpeed`；
3. 将模型中 `linear` 配置定义、计算解析器、HUD 视图与本地化字符串完全替换为 `cvk` (Continuously Variable Knob)。

**技术栈：** Swift, GFM, Xcode PBXProj, String Catalog (xcstrings)

---

### 任务 1：物理文件调整与 Xcode 项目文件同步

**文件：**
- 修改：`PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj`
- 重命名：`PhantomKnob/Model/ControlRule.swift` ➔ `PhantomKnob/Model/KnobConfig.swift`
- 重命名：`PhantomKnob/PhantomKnobTests/ControlTests.swift` ➔ `PhantomKnob/PhantomKnobTests/DemoSliderTargetTests.swift`
- 删除：`PhantomKnob/Model/SensitivityConfig.swift`
- 删除：`PhantomKnob/PhantomKnobTests/SensitivityConfigTests.swift`

- [ ] **步骤 1：重命名 ControlRule.swift 为 KnobConfig.swift 并同步修改项目配置**
  使用 `mv` 命令行将 `PhantomKnob/Model/ControlRule.swift` 重命名为 `PhantomKnob/Model/KnobConfig.swift`。
  打开项目文件 [project.pbxproj](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj)，将 `ControlRule.swift` 替换为 `KnobConfig.swift`。
  
- [ ] **步骤 2：重命名 ControlTests.swift 并同步修改项目配置**
  使用 `mv` 命令行将 `PhantomKnob/PhantomKnobTests/ControlTests.swift` 重命名为 `PhantomKnob/PhantomKnobTests/DemoSliderTargetTests.swift`。
  打开项目文件 [project.pbxproj](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj)，将 `ControlTests.swift` 替换为 `DemoSliderTargetTests.swift`。

- [ ] **步骤 3：物理删除 SensitivityConfig 关联文件**
  使用 `rm` 物理删除：
  `PhantomKnob/Model/SensitivityConfig.swift`
  `PhantomKnob/PhantomKnobTests/SensitivityConfigTests.swift`
  
- [ ] **步骤 4：在项目配置中移除删除文件的引用**
  打开项目文件 [project.pbxproj](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj)，删除含 `SensitivityConfig.swift` 和 `SensitivityConfigTests.swift` 的行（共计各 3-4 处）。

- [ ] **步骤 5：验证构建失败以确认引用修改正确**
  运行：`xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob clean build`
  预期：编译因找不到 `SensitivityConfig` / `ControlRule` 等类型而报错，但项目文件结构已正确加载新文件。

- [ ] **步骤 6：Commit**
  ```bash
  git add PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj
  git rm PhantomKnob/Model/SensitivityConfig.swift PhantomKnob/PhantomKnobTests/SensitivityConfigTests.swift
  git add PhantomKnob/Model/KnobConfig.swift PhantomKnob/PhantomKnobTests/DemoSliderTargetTests.swift
  git commit -m "refactor: rename rule and test files, delete legacy sensitivity config"
  ```

---

### 任务 2：重命名 Sensitivity ➔ knobSpeed

**文件：**
- 修改：`PhantomKnob/Control/DemoSliderTarget.swift`
- 修改：`PhantomKnob/PhantomKnobTests/DemoSliderTargetTests.swift`
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/ViewModel/KnobPanelViewModel.swift`
- 修改：`PhantomKnob/ViewModel/UserGuideViewModel.swift`

- [ ] **步骤 1：修改 DemoSliderTarget 并使其测试通过**
  修改 [DemoSliderTarget.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Control/DemoSliderTarget.swift#L9-L12)：
  将 `sensitivity` 改为 `knobSpeed`；
  修改 [DemoSliderTargetTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/DemoSliderTargetTests.swift)，将类名 `ControlTests` 更改为 `DemoSliderTargetTests`。
  
- [ ] **步骤 2：清理 KnobStateManager 废弃参数**
  修改 [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift#L74)：
  移除 `init` 中 `sensitivityConfig: SensitivityConfig = SensitivityConfig(),` 这一参数。

- [ ] **步骤 3：重构 KnobPanelViewModel 中的增量因子**
  修改 [KnobPanelViewModel.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/ViewModel/KnobPanelViewModel.swift#L100-L101)：
  将 `sensitivity` 重构为 `knobSpeed`：
  ```swift
  let knobSpeed: Float = 0.005
  let deltaValue = Float(deltaDegrees) * knobSpeed
  ```

- [ ] **步骤 4：重构 UserGuideViewModel 中的引导页面速度计算**
  修改 [UserGuideViewModel.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/ViewModel/UserGuideViewModel.swift)：
  分别在第 `157`、`173`、`178` 行处将 `sensitivity` 修改为 `knobSpeed` 并更新后面的 `deltaValue = ... * knobSpeed` 计算式。

- [ ] **步骤 5：运行测试**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob`
  确认涉及 sensitivity 的业务代码逻辑已成功对齐为 knobSpeed，且编译通过。

- [ ] **步骤 6：Commit**
  ```bash
  git commit -a -m "refactor: rename sensitivity to knobSpeed and remove unused init parameters"
  ```

---

### 任务 3：在模型及解析层重命名 Linear ➔ CVK

**文件：**
- 修改：`PhantomKnob/Model/KnobConfig.swift` (原 `ControlRule.swift`)
- 修改：`PhantomKnob/Service/ScaleResolver.swift`

- [ ] **步骤 1：重命名 KnobConfig 中的无级变速数据模型与枚举**
  打开 [KnobConfig.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/KnobConfig.swift)：
  1. 将 `struct ScaleConfigLinear` 改为 `struct ScaleConfigCVK`；
  2. 将 `ScaleConfig` 中的 `.linear(ScaleConfigLinear)` 更改为 `.cvk(ScaleConfigCVK)`；
  3. 将 `KnobConfigType` 中的 `.linear` 更改为 `.cvk`；
  4. 将 `struct LinearKnobConfig` 更改为 `struct CVKKnobConfig`；
  5. 将 `struct Knob` 中的 `linearConfig: LinearKnobConfig?` 更改为 `cvkConfig: CVKKnobConfig?`。

- [ ] **步骤 2：更新 ScaleResolver 解析逻辑**
  打开 [ScaleResolver.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/ScaleResolver.swift)：
  将 `resolveLinear` 方法修改为：
  ```swift
  static func resolveCVK(radius: Double, config: ScaleConfigCVK) -> Double? { ... }
  ```
  同步修改其内对 `ScaleConfigCVK` 各种半径和速度映射的计算公式。

- [ ] **步骤 3：Commit**
  ```bash
  git commit -a -m "refactor: rename Linear config definitions to CVK on Model and ScaleResolver"
  ```

---

### 任务 4：在业务层与视图层重命名 Linear ➔ CVK

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/Storage/KnobCustomizer.swift`
- 修改：`PhantomKnob/ViewModel/UserGuideViewModel.swift`
- 修改：`PhantomKnob/View/UserGuideView.swift`
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：重构 KnobStateManager 中的 linear 映射逻辑**
  打开 [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)：
  把所有的 `case .linear` 改为 `case .cvk`；
  把所有的 `knob.linearConfig` 改为 `knob.cvkConfig`；
  把所有的 `.linear(...)` 枚举改写为 `.cvk(...)` 并传入新类型 `ScaleConfigCVK`。

- [ ] **步骤 2：重构 KnobCustomizer 中的预设序列化逻辑**
  打开 [KnobCustomizer.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Storage/KnobCustomizer.swift)：
  将内置 JSON 配置中的 `"configType": "linear"` 全部替换为 `"configType": "cvk"`；
  将 `"linearConfig"` 项替换为 `"cvkConfig"`。

- [ ] **步骤 3：重构用户指引中的线性旋钮别名**
  在 [UserGuideViewModel.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/ViewModel/UserGuideViewModel.swift) 与 [UserGuideView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/UserGuideView.swift) 中：
  将 `linearKnob` 变量（如 `linearKnobAngle`、`linearKnobVal`、`linearKnobBaseMultiplier`、`linearKnobDiameter`）改为以 `cvkKnob` 命名；
  将枚举值（如 `.linearKnob`）更名为 `.cvkKnob`。

- [ ] **步骤 4：重构 CustomizerHUD 视图中的绑定和面板选项**
  打开 [CustomizerHUDView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/CustomizerHUDView.swift)：
  将 `linearAppearanceForm` 变量更名为 `cvkAppearanceForm`；
  把 UI 绑定的 `linearMaxRadius`、`linearMinScale` 等关联属性替换为 `cvkMaxRadius`、`cvkMinScale`；
  修改帮助文本中的默认说明，将 `sensitivity` 更改为 `speed`：
  ```swift
  HUDHelpButton(content: String(localized: "hud.cvkMaxRadius.help", defaultValue: "The maximum radius for speed scaling. Beyond this radius, the speed stays at the maximum multiplier and does not increase further."))
  ```

- [ ] **步骤 5：更新 xcstrings 语言包与本地化 Key**
  打开 [Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings)：
  将 `hud.linear` 改为 `hud.cvk`，其汉化值为 `"无级变速旋钮"`；
  将 `hud.linearMaxRadius.help` 改为 `hud.cvkMaxRadius.help`，其汉化值为：`"无级变速倍率随距离线性增长的上限边界。当手指拉到该半径之外时，旋转速度达到最大倍率，不再继续随距离增加。"`

- [ ] **步骤 6：运行项目完整测试集验证**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob`
  预期：全部编译通过，单元测试 100% 通过（且无任何遗漏的 linear 构建报错）。

- [ ] **步骤 7：Commit**
  ```bash
  git commit -a -m "refactor: complete linear-to-cvk rename in controllers, views, presets, and localization"
  ```
