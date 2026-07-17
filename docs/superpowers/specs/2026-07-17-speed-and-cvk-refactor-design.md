# Speed Naming & CVK (Continuously Variable Knob) Refactor Design Specification

This document details the refactoring plan for renaming "sensitivity" to "speed" and renaming "linear" to "cvk" (Continuously Variable Knob) across both code models and user interface elements in PhantomKnob.

## 1. Goals (重构目标)

1. **清除失效代码 (Dead Code Cleanup)**:
   * 彻底删除未被实际业务调用的 [SensitivityConfig.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/SensitivityConfig.swift) 及其测试文件 [SensitivityConfigTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/SensitivityConfigTests.swift)。
   * 清理 [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift) 构造函数中冗余的 `sensitivityConfig` 字段。
2. **术语统一为 Speed (Rename Sensitivity to knobSpeed)**:
   * 将 Swift 代码中所有用于表示缩放增量计算的 `sensitivity` 变量或参数命名统一改为 `knobSpeed`。
   * 将 UI/HUD 工具提示与本地化文本中仅存的 `sensitivity` 描述更新为 `speed`（倍率/速度）。
3. **重命名“无级变速旋钮”的底层概念为 CVK (Rename Linear to CVK)**:
   * 由于本应用尚未正式发布，不需要考虑数据向后兼容性。因此，将所有代码和序列化模型中的 `linear` 概念彻底重名为 `cvk` (Continuously Variable Knob)。
4. **规范化文件命名 (Normalize File Names)**:
   * 将承载所有旋钮配置结构体的 [ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/ControlRule.swift) 重命名为 `KnobConfig.swift`。
   * 将 [ControlTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/ControlTests.swift) 重命名为 `DemoSliderTargetTests.swift`。
   * 同步更新 Xcode 项目文件 `.pbxproj` 的关联引用。

---

## 2. Proposed Changes (详细变更设计)

### 2.1 物理文件变更 (File Operations)
* **[DELETE]** `PhantomKnob/Model/SensitivityConfig.swift`
* **[DELETE]** `PhantomKnob/PhantomKnobTests/SensitivityConfigTests.swift`
* **[RENAME]** `PhantomKnob/Model/ControlRule.swift` ➔ **`PhantomKnob/Model/KnobConfig.swift`**
* **[RENAME]** `PhantomKnob/PhantomKnobTests/ControlTests.swift` ➔ **`PhantomKnob/PhantomKnobTests/DemoSliderTargetTests.swift`**

### 2.2 Xcode 项目配置同步 (Xcode Project File)
* **[MODIFY]** [project.pbxproj](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj):
  * 移除 `SensitivityConfig.swift` 与 `SensitivityConfigTests.swift` 的引用。
  * 将 `ControlRule.swift` 替换为 `KnobConfig.swift`。
  * 将 `ControlTests.swift` 替换为 `DemoSliderTargetTests.swift`。

### 2.3 模型定义层重命名 (KnobConfig.swift & ScaleResolver.swift)
* **[MODIFY]** `KnobConfig.swift` (原 `ControlRule.swift`):
  * 将 `LinearKnobConfig` 结构体更名为 `CVKKnobConfig`。
  * 将 `ScaleConfigLinear` 结构体更名为 `ScaleConfigCVK`。
  * 将 `ScaleConfig` 枚举中的 `.linear(ScaleConfigLinear)` 变体更名为 `.cvk(ScaleConfigCVK)`。
  * 将 `KnobConfigType` 中的 `.linear` 成员更名为 `.cvk`。
  * 将 `Knob` 结构体中的 `linearConfig: LinearKnobConfig?` 更名为 `cvkConfig: CVKKnobConfig?`。
* **[MODIFY]** [ScaleResolver.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/ScaleResolver.swift):
  * 将 `resolveLinear(radius:config:)` 方法重命名为 `resolveCVK(radius:config:)`，且将形参 `ScaleConfigLinear` 类型变更为 `ScaleConfigCVK`。

### 2.4 业务逻辑层与视图模型层重构
* **[MODIFY]** [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift):
  * `init` 构造函数删除 `sensitivityConfig` 字段。
  * 将所有关联 of `case .linear` 改为 `case .cvk`，并将 `linearConfig` 改为 `cvkConfig`。
* **[MODIFY]** [DemoSliderTarget.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Control/DemoSliderTarget.swift):
  * 将 `sensitivity` 改为 `knobSpeed`。
* **[MODIFY]** [KnobPanelViewModel.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/ViewModel/KnobPanelViewModel.swift):
  * 在 `receiveRotationDelta` 中将局部变量 `sensitivity` 更改为 `knobSpeed`。
* **[MODIFY]** [UserGuideViewModel.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/ViewModel/UserGuideViewModel.swift) & [UserGuideView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/UserGuideView.swift):
  * 将与 `linearKnob` 相关的属性重命名为 `cvkKnob`（如 `linearKnobAngle` ➔ `cvkKnobAngle`、`linearKnobVal` ➔ `cvkKnobVal` 等）。
  * 将其内的 `sensitivity` 变量更改为 `knobSpeed`。
* **[MODIFY]** [KnobCustomizer.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Storage/KnobCustomizer.swift):
  * 更新预设 JSON 字典（例如 `"configType": "linear"` ➔ `"configType": "cvk"`, `"linearConfig"` ➔ `"cvkConfig"`）。

### 2.5 UI 文本与本地化变更 (HUD & Strings Catalog)
* **[MODIFY]** [CustomizerHUDView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/CustomizerHUDView.swift):
  * 重构与 `linear` 相关的视图和逻辑（如 `linearAppearanceForm` ➔ `cvkAppearanceForm` 等）。
  * 更新帮助提示词 `hud.linearMaxRadius.help` 默认英文说明为 `"The maximum radius for speed scaling. Beyond this radius, the speed stays at the maximum multiplier and does not increase further."`。
* **[MODIFY]** [Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings):
  * 针对 `hud.linearMaxRadius.help` 更新中文翻译：`"无级变速倍率随距离线性增长的上限边界。当手指拉到该半径之外时，旋转速度达到最大倍率，不再继续随距离增加。"`
  * 重命名其他包含 `linear` 的本地化 key 为 `cvk`。

---

## 3. Verification Plan (验证计划)

### Automated Tests
* 运行项目单元测试套件：
  `xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob`
* 确保编译顺利通过，且所有单元测试均能成功 Pass。

### Manual Verification
* 打开应用，通过 `CustomizerHUD` 切换到无级变速旋钮类型。
* 物理确认旋钮倍率调整、工具提示文字和翻译是否显示为“CVK/Speed”相关表述。
