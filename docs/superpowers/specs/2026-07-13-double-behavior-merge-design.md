# 双环旋钮行为合并设计规范

## 1. 业务目标
在双环旋钮模式下，外环与内环底层共用同一只手的物理手势操作，仅仅是粗调与细调的物理灵敏度不同。为了让面板布局更加精简和一致：
- 将输出映射 (Output Translation) 与映射方向 (Clockwise Action) 合并为全局单一设定，不再区分外环和内环；
- 外环灵敏度与内环灵敏度作为独立参数，仍然保留各自的倍率文本框输入。

---

## 2. 界面设计 (UI/UX)
在配置面板的“③ 旋钮行为”分类下，当类型切换至“双环旋钮”时，其子表单整体重构为：
1. **映射方式** (Output Translation) Picker。
2. **映射方向** (Clockwise Action) Picker。
3. **灵敏度调节区**：
   - 包含两个输入框，前景色分别对应外圈（橙色）和内圈（绿色）：
     - 🟠 外环灵敏度 (输入框 + "Unit per degree")
     - 🟢 内环灵敏度 (输入框 + "Unit per degree")

---

## 3. 详细设计 (Detailed Design)

### 3.1 CustomizerHUDView.swift 数据流映射与保存
为了保持底层 `DoubleKnobConfig` 数据模型的向下兼容性（即不破坏编解码和已有的 `my_knobs.json`），在 UI 读写时做如下同步：
- **数据加载 (`loadExisting()`)**：
  直接使用内环的 `translation` 与 `clockwiseAction` 变量来初始化 UI 上的统一映射和统一方向变量：
  ```swift
  self.doubleInnerTranslation = d.inner.translation
  self.doubleInnerCWAction = d.inner.clockwiseAction
  ```
- **数据保存 (`save()`)**：
  在构造 `DoubleKnobConfig` 时，外环直接同步内环的这套输入映射方式与动作触发，即：
  ```swift
  rule.doubleConfig = DoubleKnobConfig(
      inner: VirtualKnobConfig(
          ...,
          unitPerDegree: doubleInnerScale,
          translation: doubleInnerTranslation, // 🌟 统一使用 inner
          clockwiseAction: doubleInnerCWAction,
          ...
      ),
      outer: VirtualKnobConfig(
          ...,
          unitPerDegree: doubleOuterScale,
          translation: doubleInnerTranslation, // 🌟 外环强制同步内环值
          clockwiseAction: doubleInnerCWAction,
          ...
      )
  )
  ```
- **UI 触发更新**：
  在“映射方式” Picker onChange 时：
  ```swift
  doubleInnerTranslation = next
  doubleInnerCWAction = defaultAction(for: next)
  save()
  ```
  在“映射方向” Picker onChange 时：
  ```swift
  doubleInnerCWAction = next
  save()
  ```

---

## 4. 验证计划

### 4.1 编译验证
- 跑 `swift build`，确保重构过程无任何编译和语法问题。

### 4.2 联调与交互验证
1. 呼出配置面板，切换到“旋钮行为”。
2. 当类型为“双环旋钮”时，验证原来分离的外环卡片与内环卡片合二为一。
3. 更改“映射方式”（如从“滚动条”改为“音量快捷键”），验证下面的“映射方向”关联联动更新。
4. 退出配置面板并重新呼出，验证其持久化已写入 `my_knobs.json` 并被正确加载。
