# 最小响应半径提取为公共设置项实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：**
1. 在配置面板中，将“最小响应半径” Slider 重构为位于“旋钮类型”正下方的唯一公共配置项；
2. 从单旋钮、双环旋钮和无级变速三个外观子表单中移除原本冗余的响应半径调节器；
3. 实现在加载、切换和保存阶段，公共半径与底层 Model 的双向读写同步。

**架构：**
1. 在 `CustomizerHUDView.swift` 中声明 `@State private var commonMinRadius: Double = 10.0`。
2. 在 `CustomizerHUDView.swift` 的 `body` 顶层分类的“① 旋钮类型 Picker”下方追加“最小响应半径”的 Slider UI 结构。
3. 移除 `singleAppearanceForm` 底部对 `singleMinRadius` 的 VStack 滑动块。
4. 移除 `doubleAppearanceForm` 内对 `doubleInnerMinRadius` 的 VStack 滑动块。
5. 移除 `linearAppearanceForm` 内对 `linearMinRadius` 的 VStack 滑动块。
6. 更新 `loadExisting()`，在其重置 State 过程中，根据 `configType` 智能将 `commonMinRadius` 初始化为当前类型的物理最小半径。
7. 更新 `save()`，在组装 `ControlRule` 之前，把 `commonMinRadius` 的值同时同步写回给 `singleMinRadius`、`doubleInnerMinRadius` 与 `linearMinRadius` 变量中，确保写回磁盘的数据 100% 同步且兼容。

---

### 任务 1：重构 CustomizerHUDView 的数据加载、保存与变量声明

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：在 CustomizerHUDView 内引入公共变量 commonMinRadius**

在 `CustomizerHUDView.swift` 的状态定义区（L73 附近），加入 `commonMinRadius` 变量：
```swift
    @State private var liveRadius: Double? = nil
    @State private var isPinned: Bool = false
    @State private var commonMinRadius: Double = 10.0 // 🌟 新增的公共最小响应半径
```

- [ ] **步骤 2：更新 loadExisting() 方法以同步 commonMinRadius**

在 `loadExisting()` 解析完规则并为各自类型的 State 赋值后，加入如下映射代码：
```swift
        // 🌟 加载后，同步公共的最小响应半径
        switch self.configType {
        case .single:
            self.commonMinRadius = self.singleMinRadius
        case .double:
            self.commonMinRadius = self.doubleInnerMinRadius
        case .linear:
            self.commonMinRadius = self.linearMinRadius
        }
```

- [ ] **步骤 3：更新 save() 方法以同步 commonMinRadius**

在 `save()` 实例化 `ControlRule` 之前，将公共的 `commonMinRadius` 同步写入各个变量：
```swift
    private func save() {
        guard !isLoadingConfig else { return }
        
        // 🌟 保存前，把公共最小响应半径值同步给各个类型配置
        self.singleMinRadius = self.commonMinRadius
        self.doubleInnerMinRadius = self.commonMinRadius
        self.linearMinRadius = self.commonMinRadius
        
        var rule = ControlRule(key: currentRuleKey, themeColor: themeColor, configType: configType)
        ...
```

- [ ] **步骤 4：运行 swift build 验证编译**

运行：`swift build` 在 `PhantomKnob` 路径下。
预期：编译成功。

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "feat: declare commonMinRadius and map it in loadExisting/save methods"
```

---

### 任务 2：重构 CustomizerHUDView 的 UI 布局并提取公共滑块

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：在“旋钮类型”下方、第一个 Divider 上方添加公共的最小响应半径滑块**

在 `body` 里的第一个 Divider 之前添加 UI：
```swift
                    // ① 旋钮类型
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "hud.knobType", defaultValue: "旋钮类型"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Picker("", selection: $configType) {
                            Text(String(localized: "hud.single", defaultValue: "Single Knob")).tag(KnobConfigType.single)
                            Text(String(localized: "hud.double", defaultValue: "Double-Ring")).tag(KnobConfigType.double)
                            Text(String(localized: "hud.linear", defaultValue: "Variable Speed")).tag(KnobConfigType.linear)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: configType) { _ in 
                            // 切换类型时，把当前的公共响应半径带入新类型中并保存
                            save() 
                        }
                    }
                    
                    // 🌟 提取出来的唯一公共“最小响应半径”滑块
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(String(localized: "hud.minRadius", defaultValue: "最小响应半径")).font(.system(size: 11)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(commonMinRadius)) mm")
                                .font(.system(size: 11, design: .monospaced))
                        }
                        Slider(value: $commonMinRadius, in: 5.0...15.0, step: 1.0)
                            .onChange(of: commonMinRadius) { _ in
                                save()
                            }
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
```

- [ ] **步骤 2：从 singleAppearanceForm 中删除冗余的最小响应半径滑块**

移除 `singleAppearanceForm` 中原本对 `singleMinRadius` 的 Slider 定义：
```swift
            // 移除原本的：
            // VStack(alignment: .leading, spacing: 6) {
            //     HStack {
            //         Text(String(localized: "hud.minRadius", ...)).font(.system(size: 11)).foregroundColor(.secondary)
            //         Spacer()
            //         Text("\(Int(singleMinRadius)) mm")
            //             .font(.system(size: 11, design: .monospaced))
            //     }
            //     Slider(value: $singleMinRadius, in: 5.0...15.0, step: 1.0)
            //     ...
            // }
```

- [ ] **步骤 3：从 doubleAppearanceForm 中删除冗余的最小响应半径滑块**

查找 `doubleAppearanceForm`，将 `doubleInnerMinRadius` 滑动条相关的 UI VStack 整体移除。
（注意：不要错删 `doubleInnerRadiusMax` “内外环边界”和 `doubleMargin` “迟滞范围”这两个重要滑块！）

- [ ] **步骤 4：从 linearAppearanceForm 或者是 linear 的其它外观子项中删除冗余的最小响应半径滑块**

查阅 `linearAppearanceForm` 等子项，确保已经把原有的 `linearMinRadius` 调节 Slider 干净地删除。

- [ ] **步骤 5：运行 swift build 验证编译**

运行：`swift build`
预期：编译成功，无任何语法错误。

- [ ] **步骤 6：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "feat: relocate minRadius slider to common location and clean redundant sub-form inputs"
```

---

### 任务 3：系统整体集成与功能测试

**文件：**
- 修改：`/Users/wb/.gemini/antigravity-ide/brain/5eadebab-19df-4d33-9374-34d87cbe072c/walkthrough.md`

- [ ] **步骤 1：整体编译项目**

运行：`swift build`
预期：Build complete! (0.00s)

- [ ] **步骤 2：测试无级变速与多类型下公共最小半径滑块切换**
   - 呼出面板。
   - 拖动唯一的“最小响应半径”滑块，从 10mm 改到 7mm，验证 Overlay 最小死区范围实时联动收缩。
   - 切换“旋钮类型” Picker，验证“最小响应半径”维持 7mm 不变。
   - 关闭面板，重新按 C 呼出，验证其初始状态完美定格在 7mm，说明持久化完美成功。

- [ ] **步骤 3：更新 walkthrough 归档并完成**

将测试结果和最终变化在 `walkthrough.md` 中进行补充总结，整理提交。
