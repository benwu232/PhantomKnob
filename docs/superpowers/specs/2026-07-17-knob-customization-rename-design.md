# 旋钮定制重命名设计规格说明 (Knob Customization Naming Refactor)

本规格说明定义了将 `RuleLibrary`、`ControlRule` 及相关命名重构为 `KnobCustomizer`、`Knob` 的设计细节，旨在统一底层实体概念并消除职责混淆。

## 背景与目的
在当前的设计中，旋钮的定制化实体被称为“控制规则” (`ControlRule`)，存放库被称为“规则库” (`RuleLibrary`)，这会导致语义上的两个问题：
1. **语义抽象**：用户在界面中自定义的是“一个旋钮”（存储文件名即为 `my_knobs.json`），在代码中使用 `Rule` 会显得过于抽象。
2. **职责混淆**：应用已有 `KnobStateManager` 用来管理旋钮的实时交互状态，将规则库命名为 `KnobManager` 易造成读者对于“旋钮运行期交互”与“旋钮配置存储”之间的误解。

因此，将 `RuleLibrary` 更名为 `KnobCustomizer`，将 `ControlRule` 更名为 `Knob`，将 `RuleKey` 更名为 `KnobKey`，能在保持语义一致性的同时完美解决冲突。

## 详细更名映射

### 1. 文件与主要类型重命名
* **`RuleLibrary.swift`** ➔ **`KnobCustomizer.swift`**
* **`RuleLibraryTests.swift`** ➔ **`KnobCustomizerTests.swift`**
* **`class RuleLibrary`** ➔ **`class KnobCustomizer`**
* **`class RuleLibraryTests`** ➔ **`class KnobCustomizerTests`**
* **`struct ControlRule`** ➔ **`struct Knob`**
* **`struct RuleKey`** ➔ **`struct KnobKey`**

### 2. 类接口、属性与局部变量重命名
* **`KnobCustomizer.shared.saveRule(rule)`** ➔ **`KnobCustomizer.shared.saveKnob(knob)`**
* **`KnobCustomizer.shared.lookup(for: key)`** ➔ **`KnobCustomizer.shared.knob(for: key)`**
* 内存中存放列表 `private var rules: [ControlRule]` ➔ **`private var knobs: [Knob]`**
* 局部的 `rule` ➔ `knob`
* 局部的 `ruleKey` ➔ `knobKey`
* 局部的 `resolvedRule` ➔ `resolvedKnob`

### 3. 通知与日志组件更名
* **通知通知名**：`"ControlRuleDidUpdate"` ➔ **`"KnobDidUpdate"`**
* **通知扩展定义**：`Notification.Name.controlRuleDidUpdate` ➔ `Notification.Name.knobDidUpdate` (如果有)
* **日志系统分类**：`PKLogger.ruleLibrary` ➔ `PKLogger.knobCustomizer`

## 兼容性设计（数据防丢）
> [!IMPORTANT]
> 虽然 Swift 类与代码中将 `Rule` 全面替换为了 `Knob`，但为了**保证老用户的云同步及本地已保存数据不发生丢失**，底层序列化机制与 iCloud 同步键需要做防丢设计：
> 1. 本地存储路径与文件名保持 `my_knobs.json`。
> 2. 云端同步的 iCloud KVS 同步键 `"com.phantomknob.my_knobs.data"` 绝对不能更改。
> 3. `Knob` 结构体的 `CodingKeys` 应将变量映射到原有的 JSON 字段。由于目前 `my_knobs.json` 最外层是一个规则对象数组，各字段如 `key`、`themeColor`、`configType` 等均与结构体变量名吻合，可无缝平滑迁移。

## 验证计划
- 确保所有更名均在 `project.pbxproj` 中同步注册，编译不会报错。
- 执行 `KnobCustomizerTests` 及所有其他单元测试，并确保全部通过。
