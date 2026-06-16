# 剪映控件深度定制与父链层级定位匹配设计规格说明

为 PhantomKnob 引入通用的“控件层级链条定位匹配”与“点击聚焦”机制，重点适配剪映（CapCut）的参数文本框（`AXStaticText` 或 `AXTextField`）。同时，在 Customizer HUD 定制面板中支持“完整控件链层级展示”与“层级分叉比对自动区分冲突”的交互。

## 用户审查点

> [!IMPORTANT]
> 1. **父级层级匹配**：新增 `parentChain` 属性对 `RuleKey` 进行扩展。当多个控件的 Bundle ID + AXRole 发生冲突（如都是 `AXStaticText` 且无 ID）时，通过遍历父级树的角色和显示名称来唯一标识每个旋钮规则。
2. **动态过滤**：在构建和比对父链时，系统将**自动忽略 `AXWindow` 和 `AXApplication` 层级的 Title**，避免因动态项目名（如“剪映 - 项目A.draft”）导致换项目后规则失效。
3. **分叉点自动锁定**：另存为独立新旋钮时，系统自动 diff 当前控件与已有冲突规则的父链，锁定第一个相异层级节点（分叉点）并在定制面板中强制勾选，确保两套规则永不冲突。

---

## 提议的变更

### 1. 核心模型与匹配逻辑变更

#### [NEW] [ParentNodeInfo.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/ParentNodeInfo.swift) (或合并入 [ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/ControlRule.swift))
定义父级层级单个节点的信息：
```swift
struct ParentNodeInfo: Codable, Hashable {
    let axRole: String          // 节点角色，如 "AXGroup", "AXScrollArea"
    let displayName: String?    // 节点静态标题，如 "对比度", "色彩"
}
```

#### [MODIFY] [ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/ControlRule.swift)
扩展 `RuleKey` 结构以支持多层级校验：
- 新增 `parentChain: [ParentNodeInfo]?` 可选属性。
- 升级 `matches(_ other: RuleKey) -> Bool` 逻辑，在 `parentChain` 存在时强比对父节点链的 Role 与 Name。

#### [MODIFY] [DetectedTarget.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/DetectedTarget.swift)
- 扩展 `DetectedTarget` 属性，添加 `parentChain: [ParentNodeInfo]` 链。
- 升级 `ruleKey` 计算属性，使其携带当前捕获的父链特征。

#### [MODIFY] [TargetDetector.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/TargetDetector.swift)
- 放宽检测限制：允许 `AXTextField` 与 `AXStaticText` 在没有 Min/Max 属性时也被捕获为可调节目标。
- 在 `tryBuildTarget(from:)` 中，一旦捕获到合法元素，立即**向上遍历 10 层父级**：
  - 提取各级父节点的 `AXRole` 和 `AXTitle` / `AXDescription`。
  - 过滤/忽略 `AXWindow` 和 `AXApplication` 的 Title。
  - 组装成 `parentChain` 注入 `DetectedTarget`。

#### [MODIFY] [RuleLibrary.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Storage/RuleLibrary.swift)
- 升级 `lookup(for:)` 路由匹配策略，引入**具体性匹配优先**原则：
  1. *携带 parentChain 且完全符合链条校验* 的规则拥有最高优先级。
  2. 其次是精确 `identifier` 匹配的规则。
  3. 再次是 `displayName` 匹配。
  4. 最终退回到宽泛的 `bundleID + axRole` 规则。

---

### 2. 状态机与自动点击聚焦

#### [MODIFY] [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)
- 当状态机确认激活进入 `.knobing(target:)` 时，如果 `target.axRole` 为 `AXTextField` 或 `AXStaticText`：
  - 调用 `simulateClick(at: initialTouchPosition)` 自动投递鼠标左键按起事件完成对焦。
- 点击事件使用特殊的 `eventSource` 标识符 `0xDEADC0DE` 发送，以防被拦截逻辑自身过滤。

---

### 3. 定制悬浮面板交互变更

#### [MODIFY] [CustomizerHUDView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/CustomizerHUDView.swift)
- **层级树列表渲染**：
  在面板底部的定位信息卡片中，渲染出完整的 `parentChain` 控件链（排除叶子节点本身），每层显示角色及静态文本，且前置复选框供手动定制。
- **另存为新旋钮与冲突自动比对（核心机制）**：
  - 当按下 `C` 键唤起的控件已在用户/系统规则库里存在时，UI 显示：*“当前位置已匹配规则：[规则名]。修改将同步影响所有同类控件。”* 并暴露 **“另存为独立新旋钮”** 按钮。
  - 点击按钮时，自动运行 `parentChain` 比对：
    - 比对两个控件的层级链，找到第一个不同的节点（分叉点，例如“对比度”与“亮度”）。
    - 自动强制勾选该分叉节点并在 UI 上高亮显示（💡 特殊标识），禁止用户取消。
    - 重新实例化一条带有专属 `parentChain` 约束的规则并写回 `rules.json` 进行热重载。

---

## 验证计划

### 自动化测试
- 在 `RuleLibraryTests` 中编写包含多条 `parentChain` 相互冲突规则的查找逻辑，确认优先级与比对能够精确回退。
- 测试 `ParentNodeInfo` 及 `RuleKey` 的 JSON 序列化与反序列化，防止因新字段造成旧规则文件破损崩溃。

### 手动验证
1. 打开剪映，鼠标悬停于“对比度”输入框，做旋钮手势激活后按下 `C` 键，设置并保存单圈微调（`arrowKeyUpDown` 样式）。
2. 将鼠标悬停到相邻的“亮度”输入框，同样激活后按下 `C` 键。面板提示发现冲突，点击“另存为独立新旋钮”。
3. 检查 HUD 上是否展示了层级链并自动高亮锁定了“亮度”与“对比度”的分叉层级。
4. 确认保存后，两个旋钮能够根据鼠标悬停位置各自独立响应，互不干扰，换项目或拖拽面板后也保持稳定。
