# 剪映文本框聚焦与通用 AX 诊断工具设计规格说明

为剪映（CapCut）的参数文本框（`AXStaticText` 或 `AXTextField`）引入“点击聚焦 + 方向键调节”的自动控制支持，并编写一个通用的独立辅助诊断工具。

## 用户审查点

> [!NOTE]
> 为了安全起见，我们在 `TargetDetector` 中放宽 `AXMinValue`/`AXMaxValue` 限制时，仅针对 `AXTextField` 和 `AXStaticText` 两个角色，且只有在规则库（RuleLibrary）中已显式配置对应规则时，才视其为“可调节”控件。这可以完全避免在其他未适配的应用中因误判导致乱点鼠标的问题。

## 提议的变更

### 1. 独立诊断工具（通用）

#### [NEW] [inspect_ax_tool.swift](file:///Users/wb/work/phantom_knob_mac/scripts/inspect_ax_tool.swift)
一个通用的、交互式的命令行诊断工具。用户启动工具后可切换到目标应用，将鼠标移动到想要控制的元素上，通过触发事件来进行精确检测，并将结果实时打印并持久化保存：
- **触发机制**：支持以下两种全局触发方式：
  1. **鼠标点击触发**：当用户在目标应用中点击某个元素时（捕获全局 `leftMouseUp` 事件），自动对其进行检测。
  2. **全局热键触发**：按下指定热键（默认为 `Control + Shift + D`），自动检测当前鼠标悬停的元素。
- **检测逻辑**：
  - 获取触发瞬间鼠标指针下方的窗口和运行应用。
  - 向上遍历其 Accessibility (AX) 父节点链条（深度最大为 10）。
  - 提取并打印各层级节点的详细属性（Role、Subrole、Title、Identifier、Description、可写入属性、可用 Actions、Value/MinValue/MaxValue）。
- **结果输出**：
  - 实时在终端中以清晰的树状结构打印检测到的节点信息。
  - 自动向当前目录下的 `inspect_results.txt` 文件追加保存该次检测结果。
  - 给出推荐的 PhantomKnob 规则配置（JSON 格式）。
- **退出机制**：终端按下 `Control + C` 退出工具。

### 2. PhantomKnob 应用核心

#### [MODIFY] [TargetDetector.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/TargetDetector.swift)
修改 `tryBuildTarget` 方法以放宽限制条件：
- 默认情况下，元素依然要求具备 `AXMinValue` 和 `AXMaxValue` 属性。
- **特例**：如果元素的 Role 为 `AXTextField` 或 `AXStaticText`，即便没有 Min/Max 属性，也允许返回有效的 `DetectedTarget`。

#### [MODIFY] [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)
集成自动点击聚焦逻辑：
- 当状态机向 `.knobing(target:)` 状态转移的瞬间：
  - 若 `target.axRole` 为 `"AXTextField"` 或 `"AXStaticText"`：
    - 在当前鼠标位置 `initialTouchPosition` 注入一次鼠标左键点击事件（`leftMouseDown` 后紧跟 `leftMouseUp`）以使文本框获得焦点。
- 确保点击事件带上特殊的 `eventSource` 标识符 `0xDEADC0DE` 或使用 HID tap 发送，避免被我们自身的手势监听器重新拦截导致死循环。

#### [MODIFY] [bundled-rules.json](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/App/bundled-rules.json)
增加剪映文本框的映射规则，将旋转翻译为 `arrowKeyUpDown`（上下键）：
- 目标应用：`com.lemon.jianying`、`com.lemon.jianyingpro`、`com.lemon.lv`、`com.lemon.lvoverseas`
- 角色：`AXStaticText`、`AXTextField`
- 翻译策略：`arrowKeyUpDown`
- 灵敏度配置：`fixed(1.0)`

---

## 验证计划

### 自动化测试
- 运行 `PhantomKnobTests` 确保对已有应用规则的解析和匹配逻辑没有发生退化（Regression）。

### 手动验证步骤
1. 在终端运行 `swift scripts/inspect_ax_tool.swift`，将鼠标移动到剪映的参数文本框上，确认其被精准识别为 `AXStaticText` 且输出对应的分级层级信息。
2. 启动 PhantomKnob，将鼠标悬停在剪映“调节”面板的任一参数输入框（例如“对比度”的数值文本框）上方，在触控板上做双指旋转手势。
3. 验证文本框是否被自动点击并出现输入光标（即获得焦点），且数值随着旋转方向上下递增或递减。
4. 验证在时间轴面板上旋转时，依然正常执行 `arrowKeyLeftRight` 的逐帧穿梭控制，未被误触发为点击。
