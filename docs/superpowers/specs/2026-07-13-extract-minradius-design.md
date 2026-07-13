# 最小响应半径提取为公共设置项设计规范

## 1. 业务目标
在原先的旋钮定制面板中，“最小响应半径”配置作为各自旋钮类型的独立属性，分散在单旋钮外观、双旋钮外观和线性外观等各个子表单中。这导致了：
- 面板内容显得重复和冗余；
- 用户在切换旋钮类型时，无法直接复用已调节好的最小物理响应半径。

为了精简配置面板，将“最小响应半径”统一提取为顶层唯一的公共配置项，同时保持底层数据模型的向下兼容性。

---

## 2. 界面设计 (UI/UX)
- **位置调整**：
  - 从“旋钮外观”下的单旋钮外观、双旋钮外观（“最小响应半径” Slider）以及无级变速外观的子表单中彻底移除“最小响应半径”的 Slider 配置项。
  - 将该滑块提取出来，整体安置在分类 “① 旋钮类型” SegmentedPicker 的正下方，位于第一条分割线 Divider 之上。
- **滑块样式**：
  - 左侧显示标签：“最小响应半径”
  - 右侧显示数值：“X mm” (等宽字体)
  - 阻尼范围维持在 `5.0...15.0` mm，步长为 `1.0`。

---

## 3. 详细设计 (Detailed Design)

### 3.1 CustomizerHUDView.swift 状态控制与双向同步
- **定义公共变量**：
  在 `CustomizerHUDView` 中引入 `@State private var commonMinRadius: Double = 10.0`。
- **在加载 `loadExisting()` 时映射**：
  ```swift
  switch configType {
  case .single:
      commonMinRadius = singleMinRadius
  case .double:
      commonMinRadius = doubleInnerMinRadius
  case .linear:
      commonMinRadius = linearMinRadius
  }
  ```
- **在保存 `save()` 时同步**：
  在构造 `ControlRule` 前，将 `commonMinRadius` 的最新数值写回到各个子项的 State 变量中：
  ```swift
  singleMinRadius = commonMinRadius
  doubleInnerMinRadius = commonMinRadius
  linearMinRadius = commonMinRadius
  ```
  然后再常规实例化 `ControlRule` 并保存：
  ```swift
  switch configType {
  case .single:
      rule.singleConfig = SingleKnobConfig(..., minRadius: commonMinRadius)
  case .double:
      rule.doubleConfig = DoubleKnobConfig(
          inner: VirtualKnobConfig(minRadius: commonMinRadius, ...),
          outer: VirtualKnobConfig(minRadius: doubleInnerRadiusMax, ...) // 外圈最小半径为内圈最大半径，不影响
      )
  case .linear:
      rule.linearConfig = LinearKnobConfig(minRadius: commonMinRadius, ...)
  }
  ```

---

## 4. 验证计划

### 4.1 手工联调测试
1. 呼出真实 Overlay，按 C 键弹出配置面板。
2. 验证“最小响应半径” Slider 整体从三大分类外观中消失，只在“旋钮类型”正下方存在唯一的全局 Slider。
3. 拖动此唯一的“最小响应半径” Slider（例如将其从默认 10mm 改为 8mm），然后点击颜色或更改其他参数：
   - 验证 Overlay 配色即时更新，且此时的最小圆环在没有手指触碰时，静态渲染直径与 8mm 物理尺寸自适应对齐。
4. 切换“旋钮类型” Picker（如从“单旋钮”切换为“无级变速”）：
   - 验证滑块的“最小响应半径”维持在 8mm 保持不变，并同步自动应用到无级变速模式中。
5. 退出配置面板后，重新呼出：
   - 验证滑块及底层配置完美维持在 8mm，证明持久化持久保存成功。
