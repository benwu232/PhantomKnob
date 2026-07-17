# 旋钮定制重命名 (Knob Rename) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将项目中所有基于“Rule”的命名（如 `RuleLibrary`、`ControlRule`、`RuleKey` 等）彻底重构替换为纯粹直观的“Knob”及“Customizer”关联命名，并更新工程文件和单元测试，且保证 iCloud 同步与本地文件数据向后兼容。

**架构：** 
1. 重命名核心模型 `ControlRule` 为 `Knob`，`RuleKey` 为 `KnobKey`。
2. 重命名规则库类 `RuleLibrary` 为 `KnobCustomizer`，其方法如 `saveRule` 变更为 `saveKnob`，`lookup` 变更为 `knob`。
3. 全局重命名所有调用处的类名、变量名、通知及日志，并修改 Xcode 项目文件引用。

**技术栈：** Swift, Combine, macOS ServiceManagement/Accessibility APIs, Xcode Project File format.

---

## 计划涉及文件清单

### 数据与逻辑层
* **`PhantomKnob/Model/ControlRule.swift`** [修改] -> 内嵌重命名核心模型
* **`PhantomKnob/Storage/RuleLibrary.swift`** [删除] ➔ **`PhantomKnob/Storage/KnobCustomizer.swift`** [新增]
* **`PhantomKnob/Service/CloudSyncManager.swift`** [修改] -> 替换接口及同步映射调用
* **`PhantomKnob/Service/KnobStateManager.swift`** [修改] -> 替换匹配及状态重载逻辑
* **`PhantomKnob/ViewModel/UserGuideViewModel.swift`** [修改] -> 更新新手指南模拟控件查找

### 视图层
* **`PhantomKnob/View/CustomizerHUDView.swift`** [修改] -> 替换配置面板匹配、检测冲突与保存动作

### 测试层
* **`PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift`** [删除] ➔ **`PhantomKnob/PhantomKnobTests/KnobCustomizerTests.swift`** [新增]
* **`PhantomKnob/PhantomKnobTests/CloudSyncManagerTests.swift`** [修改] -> 替换测试中的 `RuleLibrary` 引用
* **`PhantomKnob/PhantomKnobTests/GestureConflictTests.swift`** [修改] -> 替换测试中的注入和匹配引用

### 工程配置文件
* **`PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj`** [修改] -> 更改磁盘实体文件路径映射

---

## 详细步骤说明

### 任务 1：重命名核心模型与键定义

**文件：**
- 修改：`PhantomKnob/Model/ControlRule.swift`

- [ ] **步骤 1：修改 `ControlRule.swift` 类型声明**
  替换 `ParentNodeInfo`、`RuleKey` ➔ `KnobKey`，`ControlRule` ➔ `Knob`，并更新全部的内部兼容映射构造函数与解码逻辑。
  修改后的完整内容见如下定义：
  ```swift
  // PhantomKnob/Model/ControlRule.swift
  import Foundation

  struct ParentNodeInfo: Codable, Hashable, Equatable {
      let axRole: String
      let displayName: String?
  }

  struct KnobKey: Codable, Hashable {
      let bundleID: String
      let axRole: String
      let identifier: String?
      let displayName: String?
      let parentChain: [ParentNodeInfo]?

      init(bundleID: String, axRole: String, identifier: String? = nil, displayName: String? = nil, parentChain: [ParentNodeInfo]? = nil) {
          self.bundleID = bundleID
          self.axRole = axRole
          self.identifier = identifier
          self.displayName = displayName
          self.parentChain = parentChain
      }

      func matches(_ other: KnobKey) -> Bool {
          bundleID == other.bundleID &&
          axRole == other.axRole &&
          (identifier == nil || identifier == other.identifier) &&
          (displayName == nil || displayName == other.displayName) &&
          (parentChain == other.parentChain)
      }
  }

  struct RadiusZone: Codable, Equatable {
      let minRadius: Double
      let maxRadius: Double
      let margin: Double
      let scale: Double
  }

  struct ScaleConfigLinear: Codable, Equatable {
      let minRadius: Double
      let maxRadius: Double
      let minScale: Double
      let maxScale: Double
  }

  enum ScaleConfig: Codable, Equatable {
      case fixed(Double)
      case zones([RadiusZone])
      case linear(ScaleConfigLinear)
  }

  enum KnobConfigType: String, Codable {
      case single
      case double
      case linear
  }

  struct SingleKnobConfig: Codable, Equatable {
      var unitPerDegree: Double
      var translation: InputTranslation
      var clockwiseAction: String
      var minRadius: Double?
  }

  struct VirtualKnobConfig: Codable, Equatable {
      var minRadius: Double
      var maxRadius: Double
      var margin: Double
      var unitPerDegree: Double
      var translation: InputTranslation
      var clockwiseAction: String
      var themeColor: String?
  }

  struct DoubleKnobConfig: Codable, Equatable {
      var inner: VirtualKnobConfig
      var outer: VirtualKnobConfig
  }

  struct LinearKnobConfig: Codable, Equatable {
      var minRadius: Double
      var maxRadius: Double
      var minScale: Double
      var maxScale: Double
      var translation: InputTranslation
      var clockwiseAction: String
      var outerThemeColor: String?
      var innerThemeColor: String?

      init(minRadius: Double,
           maxRadius: Double,
           minScale: Double,
           maxScale: Double,
           translation: InputTranslation,
           clockwiseAction: String,
           outerThemeColor: String? = nil,
           innerThemeColor: String? = nil) {
          self.minRadius = minRadius
          self.maxRadius = maxRadius
          self.minScale = minScale
          self.maxScale = maxScale
          self.translation = translation
          self.clockwiseAction = clockwiseAction
          self.outerThemeColor = outerThemeColor
          self.innerThemeColor = innerThemeColor
      }
  }

  struct Knob: Codable, Equatable {
      let key: KnobKey
      var themeColor: String?
      var configType: KnobConfigType
      
      var singleConfig: SingleKnobConfig?
      var doubleConfig: DoubleKnobConfig?
      var linearConfig: LinearKnobConfig?
      
      var extra: [String: String]?
      
      var translation: InputTranslation?
      var scaleConfig: ScaleConfig?
      var invert: Bool?
      var overlayStyle: String?
      var rotationStyle: String?

      enum CodingKeys: String, CodingKey {
          case key, themeColor, configType, singleConfig, doubleConfig, linearConfig, extra
          case translation, scaleConfig, invert, overlayStyle, rotationStyle
      }

      init(key: KnobKey,
           themeColor: String? = nil,
           configType: KnobConfigType = .single,
           singleConfig: SingleKnobConfig? = nil,
           doubleConfig: DoubleKnobConfig? = nil,
           linearConfig: LinearKnobConfig? = nil,
           extra: [String: String]? = nil) {
          self.key = key
          self.themeColor = themeColor
          self.configType = configType
          self.singleConfig = singleConfig
          self.doubleConfig = doubleConfig
          self.linearConfig = linearConfig
          self.extra = extra
          
          if configType == .single, let single = singleConfig {
              self.translation = single.translation
              self.scaleConfig = .fixed(single.unitPerDegree)
              self.invert = (single.clockwiseAction == "arrowDown" || single.clockwiseAction == "arrowLeft" || single.clockwiseAction == "scrollDown" || single.clockwiseAction == "scrollLeft" || single.clockwiseAction == "swipeDown" || single.clockwiseAction == "swipeLeft" || single.clockwiseAction == "decrease")
          }
      }

      init(key: KnobKey,
           translation: InputTranslation,
           scaleConfig: ScaleConfig = .fixed(1.0),
           themeColor: String? = nil,
           overlayStyle: String? = nil,
           rotationStyle: String? = nil,
           invert: Bool? = false,
           extra: [String: String]? = nil) {
          self.key = key
          self.themeColor = themeColor
          self.overlayStyle = overlayStyle
          self.rotationStyle = rotationStyle
          self.extra = extra
          
          let oldInvert = invert ?? false
          let defaultCWAction: String
          switch translation {
          case .arrowKeyUpDown: defaultCWAction = oldInvert ? "arrowDown" : "arrowUp"
          case .arrowKeyLeftRight: defaultCWAction = oldInvert ? "arrowLeft" : "arrowRight"
          case .scrollWheelVertical: defaultCWAction = oldInvert ? "scrollDown" : "scrollUp"
          case .scrollWheelHorizontal: defaultCWAction = oldInvert ? "scrollRight" : "scrollLeft"
          case .swipeVertical: defaultCWAction = oldInvert ? "swipeDown" : "swipeUp"
          case .swipeHorizontal: defaultCWAction = oldInvert ? "swipeRight" : "swipeLeft"
          case .axWrite: defaultCWAction = oldInvert ? "decrease" : "increase"
          }
          
          self.translation = translation
          self.scaleConfig = scaleConfig
          self.invert = invert
          
          switch scaleConfig {
          case .zones(let zones):
              self.configType = .double
              let innerZone = zones.count > 0 ? zones[0] : RadiusZone(minRadius: 5.0, maxRadius: 25.0, margin: 2.0, scale: 1.0)
              let outerZone = zones.count > 1 ? zones[1] : RadiusZone(minRadius: 27.0, maxRadius: 100.0, margin: 2.0, scale: 1.0)
              self.doubleConfig = DoubleKnobConfig(
                  inner: VirtualKnobConfig(minRadius: innerZone.minRadius, maxRadius: innerZone.maxRadius, margin: innerZone.margin, unitPerDegree: innerZone.scale, translation: translation, clockwiseAction: defaultCWAction),
                  outer: VirtualKnobConfig(minRadius: outerZone.minRadius, maxRadius: outerZone.maxRadius, margin: outerZone.margin, unitPerDegree: outerZone.scale, translation: translation, clockwiseAction: defaultCWAction)
              )
          case .linear(let config):
              self.configType = .linear
              self.linearConfig = LinearKnobConfig(
                  minRadius: config.minRadius,
                  maxRadius: config.maxRadius,
                  minScale: config.minScale,
                  maxScale: config.maxScale,
                  translation: translation,
                  clockwiseAction: defaultCWAction,
                  outerThemeColor: themeColor,
                  innerThemeColor: themeColor
              )
          case .fixed(let val):
              self.configType = .single
              self.singleConfig = SingleKnobConfig(unitPerDegree: val, translation: translation, clockwiseAction: defaultCWAction)
          }
      }

      init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          self.key = try container.decode(KnobKey.self, forKey: .key)
          self.themeColor = try container.decodeIfPresent(String.self, forKey: .themeColor)
          self.extra = try container.decodeIfPresent([String: String].self, forKey: .extra)
          self.overlayStyle = try container.decodeIfPresent(String.self, forKey: .overlayStyle)
          self.rotationStyle = try container.decodeIfPresent(String.self, forKey: .rotationStyle)
          
          if let configTypeStr = try container.decodeIfPresent(String.self, forKey: .configType),
             let parsedType = KnobConfigType(rawValue: configTypeStr) {
              self.configType = parsedType
              self.singleConfig = try container.decodeIfPresent(SingleKnobConfig.self, forKey: .singleConfig)
              self.doubleConfig = try container.decodeIfPresent(DoubleKnobConfig.self, forKey: .doubleConfig)
              self.linearConfig = try container.decodeIfPresent(LinearKnobConfig.self, forKey: .linearConfig)
              
              let decodedTrans = try container.decodeIfPresent(InputTranslation.self, forKey: .translation)
              let decodedScale = try container.decodeIfPresent(ScaleConfig.self, forKey: .scaleConfig)
              let decodedInvert = try container.decodeIfPresent(Bool.self, forKey: .invert)
              
              if let single = self.singleConfig {
                  self.translation = decodedTrans ?? single.translation
                  self.scaleConfig = decodedScale ?? .fixed(single.unitPerDegree)
                  self.invert = decodedInvert ?? (single.clockwiseAction == "arrowDown" || single.clockwiseAction == "arrowLeft" || single.clockwiseAction == "scrollDown" || single.clockwiseAction == "scrollLeft" || single.clockwiseAction == "swipeDown" || single.clockwiseAction == "swipeLeft" || single.clockwiseAction == "decrease")
              } else if let double = self.doubleConfig {
                  self.translation = decodedTrans ?? double.inner.translation
                  self.scaleConfig = decodedScale ?? .zones([
                      RadiusZone(minRadius: double.inner.minRadius, maxRadius: double.inner.maxRadius, margin: double.inner.margin, scale: double.inner.unitPerDegree),
                      RadiusZone(minRadius: double.outer.minRadius, maxRadius: double.outer.maxRadius, margin: double.outer.margin, scale: double.outer.unitPerDegree)
                  ])
                  self.invert = decodedInvert ?? (double.inner.clockwiseAction == "arrowDown" || double.inner.clockwiseAction == "arrowLeft" || double.inner.clockwiseAction == "scrollDown" || double.inner.clockwiseAction == "scrollLeft" || double.inner.clockwiseAction == "swipeDown" || double.inner.clockwiseAction == "swipeLeft" || double.inner.clockwiseAction == "decrease")
              } else if let linear = self.linearConfig {
                  self.translation = decodedTrans ?? linear.translation
                  self.scaleConfig = decodedScale ?? .linear(ScaleConfigLinear(minRadius: linear.minRadius, maxRadius: linear.maxRadius, minScale: linear.minScale, maxScale: linear.maxScale))
                  self.invert = decodedInvert ?? (linear.clockwiseAction == "arrowDown" || linear.clockwiseAction == "arrowLeft" || linear.clockwiseAction == "scrollDown" || linear.clockwiseAction == "scrollLeft" || linear.clockwiseAction == "swipeDown" || linear.clockwiseAction == "swipeLeft" || linear.clockwiseAction == "decrease")
              } else {
                  self.translation = decodedTrans
                  self.scaleConfig = decodedScale
                  self.invert = decodedInvert
              }
          } else {
              let oldTrans = try container.decodeIfPresent(InputTranslation.self, forKey: .translation) ?? .scrollWheelVertical
              let oldScaleConfig = try container.decodeIfPresent(ScaleConfig.self, forKey: .scaleConfig) ?? .fixed(1.0)
              let oldInvertOpt = try container.decodeIfPresent(Bool.self, forKey: .invert)
              let oldInvert = oldInvertOpt ?? false
              
              self.translation = oldTrans
              self.scaleConfig = oldScaleConfig
              self.invert = oldInvertOpt
              
              let defaultCWAction: String
              switch oldTrans {
              case .arrowKeyUpDown: defaultCWAction = oldInvert ? "arrowDown" : "arrowUp"
              case .arrowKeyLeftRight: defaultCWAction = oldInvert ? "arrowLeft" : "arrowRight"
              case .scrollWheelVertical: defaultCWAction = oldInvert ? "scrollDown" : "scrollUp"
              case .scrollWheelHorizontal: defaultCWAction = oldInvert ? "scrollRight" : "scrollLeft"
              case .swipeVertical: defaultCWAction = oldInvert ? "swipeDown" : "swipeUp"
              case .swipeHorizontal: defaultCWAction = oldInvert ? "swipeRight" : "swipeLeft"
              case .axWrite: defaultCWAction = oldInvert ? "decrease" : "increase"
              }
              
              switch oldScaleConfig {
              case .zones(let zones):
                  self.configType = .double
                  let innerZone = zones.count > 0 ? zones[0] : RadiusZone(minRadius: 5.0, maxRadius: 25.0, margin: 2.0, scale: 1.0)
                  let outerZone = zones.count > 1 ? zones[1] : RadiusZone(minRadius: 27.0, maxRadius: 100.0, margin: 2.0, scale: 1.0)
                  self.doubleConfig = DoubleKnobConfig(
                      inner: VirtualKnobConfig(minRadius: innerZone.minRadius, maxRadius: innerZone.maxRadius, margin: innerZone.margin, unitPerDegree: innerZone.scale, translation: oldTrans, clockwiseAction: defaultCWAction),
                      outer: VirtualKnobConfig(minRadius: outerZone.minRadius, maxRadius: outerZone.maxRadius, margin: outerZone.margin, unitPerDegree: outerZone.scale, translation: oldTrans, clockwiseAction: defaultCWAction)
                  )
              case .linear(let config):
                  self.configType = .linear
                  self.linearConfig = LinearKnobConfig(
                      minRadius: config.minRadius,
                      maxRadius: config.maxRadius,
                      minScale: config.minScale,
                      maxScale: config.maxScale,
                      translation: oldTrans,
                      clockwiseAction: defaultCWAction,
                      outerThemeColor: themeColor,
                      innerThemeColor: themeColor
                  )
              case .fixed(let val):
                  self.configType = .single
                  self.singleConfig = SingleKnobConfig(unitPerDegree: val, translation: oldTrans, clockwiseAction: defaultCWAction)
              }
          }
      }
  }

  extension ScaleConfig {
      private enum CodingKeys: String, CodingKey {
          case fixed
          case zones
          case linear
      }

      init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          if let val = try? container.decode(Double.self, forKey: .fixed) {
              self = .fixed(val)
          } else if let zones = try? container.decode([RadiusZone].self, forKey: .zones) {
              self = .zones(zones)
          } else if let linear = try? container.decode(ScaleConfigLinear.self, forKey: .linear) {
              self = .linear(linear)
          } else {
              self = .fixed(1.0)
          }
      }

      func encode(to encoder: Encoder) throws {
          var container = encoder.container(keyedBy: CodingKeys.self)
          switch self {
          case .fixed(let val):
              try container.encode(val, forKey: .fixed)
          case .zones(let zones):
              try container.encode(zones, forKey: .zones)
          case .linear(let linear):
              try container.encode(linear, forKey: .linear)
          }
      }

      func resolve(radius: Double = 0) -> Double {
          switch self {
          case .fixed(let s): return s
          case .zones(let zones): return zones.first?.scale ?? 1.0
          case .linear(let linear): return linear.minScale
          }
      }
  }
  ```

- [ ] **步骤 2：验证编译**
  暂时可能无法全通，运行基本 Swift 校验：
  运行：`swiftc -c PhantomKnob/Model/ControlRule.swift`
  预期：PASS (或提示个别引用错误，模型内部自身无语法错)

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Model/ControlRule.swift
  git commit -m "refactor: rename RuleKey to KnobKey and ControlRule to Knob"
  ```

---

### 任务 2：创建 `KnobCustomizer` 替换 `RuleLibrary`

**文件：**
- 新增：`PhantomKnob/Storage/KnobCustomizer.swift`
- 删除：`PhantomKnob/Storage/RuleLibrary.swift`

- [ ] **步骤 1：复制并修改文件**
  将 `RuleLibrary.swift` 的逻辑复制到 `KnobCustomizer.swift`，执行所有的文字替换：
  * `RuleLibrary` ➔ `KnobCustomizer`
  * `ControlRule` ➔ `Knob`
  * `RuleKey` ➔ `KnobKey`
  * `saveRule` ➔ `saveKnob`
  * `lookup` ➔ `knob`
  * `PKLogger.ruleLibrary` ➔ `PKLogger.knobCustomizer`
  * 通知名 `"ControlRuleDidUpdate"` ➔ `"KnobDidUpdate"`

  重构后的核心逻辑示例如下：
  ```swift
  // PhantomKnob/Storage/KnobCustomizer.swift
  import Foundation
  import os

  final class KnobCustomizer {
      static let shared = KnobCustomizer()

      private var knobs: [Knob] = []

      internal var myKnobsURL: URL = {
          let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
          return appSupport
              .appendingPathComponent("PhantomKnob", isDirectory: true)
              .appendingPathComponent("my_knobs.json")
      }()

      init() {
          reload()
      }

      func reload() {
          var loaded: [Knob] = []
          if !FileManager.default.fileExists(atPath: myKnobsURL.path) {
              setupDefaultMyKnobs()
          }
          if let myKnobsList = loadKnobs(from: myKnobsURL) {
              loaded.append(contentsOf: myKnobsList)
          }
          // pro-rules ➔ 仍然读取 app bundle 的 pro-rules，数据结构转为 Knob
          if let proRulesDir = Bundle.main.resourceURL?.appendingPathComponent("pro-rules") {
              if FileManager.default.fileExists(atPath: proRulesDir.path) {
                  if let files = try? FileManager.default.contentsOfDirectory(at: proRulesDir, includingPropertiesForKeys: nil) {
                      for file in files where file.pathExtension == "json" {
                          if let items = loadKnobs(from: file) {
                              loaded.append(contentsOf: items)
                          }
                      }
                  }
              }
          }
          self.knobs = loaded
      }

      // setupDefaultMyKnobs 内部的 JSON 字符串映射为 Knob，myKnobsURL 路径保持不变以保证老用户本地数据安全
      private func setupDefaultMyKnobs() {
          // JSON 内容不变，由于 Knob/KnobKey 编码字段保持原样，直接写入磁盘即可
          ...
      }

      func knob(for knobKey: KnobKey) -> Knob? {
          // lookup 功能重命名为 knob(for:)
          if let targetChain = knobKey.parentChain, !targetChain.isEmpty {
              let matched = knobs.first(where: { item in
                  guard let ruleChain = item.key.parentChain, !ruleChain.isEmpty else { return false }
                  return item.key.bundleID == knobKey.bundleID &&
                         item.key.axRole == knobKey.axRole &&
                         Self.matchParentChain(ruleChain: ruleChain, targetChain: targetChain)
              })
              if let match = matched { return match }
          }
          // 后续检索匹配 KnobKey 的各项规则...
          ...
      }

      func saveKnob(_ knob: Knob) {
          // 原 saveRule
          ...
          NotificationCenter.default.post(
              name: NSNotification.Name("KnobDidUpdate"),
              object: nil,
              userInfo: ["knob": knob]
          )
      }
      
      ...
  }
  ```

- [ ] **步骤 2：物理删除旧文件 `RuleLibrary.swift`**
  运行：`rm PhantomKnob/Storage/RuleLibrary.swift`

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Storage/KnobCustomizer.swift
  git rm PhantomKnob/Storage/RuleLibrary.swift
  git commit -m "refactor: rename RuleLibrary to KnobCustomizer and delete old file"
  ```

---

### 任务 3：更新工程文件映射

**文件：**
- 修改：`PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj`

- [ ] **步骤 1：全局替换 project.pbxproj 引用**
  将工程文件里的 `RuleLibrary.swift` 替换为 `KnobCustomizer.swift`，`RuleLibraryTests.swift` 替换为 `KnobCustomizerTests.swift`。
  由于直接手动替换可能会破坏 pbxproj 结构，请使用简单的脚本或精确匹配做替换：
  * `RuleLibrary.swift` ➔ `KnobCustomizer.swift`
  * `RuleLibraryTests.swift` ➔ `KnobCustomizerTests.swift`

- [ ] **步骤 2：Commit**
  ```bash
  git add PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj
  git commit -m "build: update Xcode project file references for renamed files"
  ```

---

### 任务 4：重构调用逻辑与业务模块

**文件：**
- 修改：`PhantomKnob/Service/CloudSyncManager.swift`
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`
- 修改：`PhantomKnob/ViewModel/UserGuideViewModel.swift`

- [ ] **步骤 1：重构 `CloudSyncManager.swift`**
  把 `syncLocalRulesToCloud()` 改为 `syncLocalKnobsToCloud()`，将引用的 `RuleLibrary.shared` 改为 `KnobCustomizer.shared`，同步的通知监听由 `"ControlRuleDidUpdate"` ➔ `"KnobDidUpdate"`。
  注意：**保持 iCloud 端的 Key `"com.phantomknob.my_knobs.data"` 绝对不变**以保证云端向前兼容！

- [ ] **步骤 2：重构 `KnobStateManager.swift`**
  修改任何查询 `RuleLibrary.shared.lookup` 的地方为 `KnobCustomizer.shared.knob(for:)`。
  更新通知名称，将局部的 `rule` 变量更名为 `knob`。

- [ ] **步骤 3：重构 `CustomizerHUDView.swift`**
  修改 `save()` 方法中的保存操作为 `KnobCustomizer.shared.saveKnob(knob)`。
  修改冲突比对逻辑中 `RuleLibrary.shared.lookup` 为 `KnobCustomizer.shared.knob`。

- [ ] **步骤 4：重构 `UserGuideViewModel.swift`**
  修改演示页面控件查询中 `RuleLibrary.shared.lookup` ➔ `KnobCustomizer.shared.knob`。

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/Service/CloudSyncManager.swift PhantomKnob/Service/KnobStateManager.swift PhantomKnob/View/CustomizerHUDView.swift PhantomKnob/ViewModel/UserGuideViewModel.swift
  git commit -m "refactor: adjust businesses and services to call KnobCustomizer and Knob"
  ```

---

### 任务 5：重定义并更新测试套件

**文件：**
- 新增：`PhantomKnob/PhantomKnobTests/KnobCustomizerTests.swift`
- 删除：`PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift`
- 修改：`PhantomKnob/PhantomKnobTests/CloudSyncManagerTests.swift`
- 修改：`PhantomKnob/PhantomKnobTests/GestureConflictTests.swift`

- [ ] **步骤 1：复制并重构规则库测试**
  将 `RuleLibraryTests.swift` 复制为 `KnobCustomizerTests.swift`，并将全部的 `RuleLibrary` 替换为 `KnobCustomizer`，`ControlRule` ➔ `Knob`，`RuleKey` ➔ `KnobKey`。
  删除旧测试文件 `RuleLibraryTests.swift`：
  运行：`rm PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift`

- [ ] **步骤 2：更新 `CloudSyncManagerTests.swift` 与 `GestureConflictTests.swift`**
  修改其中所有涉及 `RuleLibrary` 的 Mock 注入及匹配调用为 `KnobCustomizer` 与 `Knob` 相关逻辑。

- [ ] **步骤 3：验证全部测试通过**
  在终端中构建并运行测试套件以验证重构成功：
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnobTests -destination 'platform=macOS'`
  预期：全部测试用例 PASS，且没有编译 Warning。

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/PhantomKnobTests/KnobCustomizerTests.swift PhantomKnob/PhantomKnobTests/CloudSyncManagerTests.swift PhantomKnob/PhantomKnobTests/GestureConflictTests.swift
  git rm PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift
  git commit -m "test: rename RuleLibraryTests to KnobCustomizerTests and update other test suites"
  ```
