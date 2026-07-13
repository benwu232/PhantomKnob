# 双环旋钮行为合并实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：**
1. 重构双环旋钮的“旋钮行为”设置面板，实现外环与内环共用统一的映射方式与映射方向 Picker；
2. 外环灵敏度与内环灵敏度继续独立配置，保持设计语言的统一与精炼；
3. 双向同步 UI 操作至底层的 `DoubleKnobConfig` 字段中，确保向下兼容。

**方案逻辑：**
- 数据加载 (`loadExisting()`) 时，以 `doubleInnerTranslation` 和 `doubleInnerCWAction` 填充 UI。
- 数据保存 (`save()`) 时，将此统一的映射和方向，同时赋值给 `DoubleKnobConfig` 的 `inner` 和 `outer` 两个子配置。

---

### 任务 1：重构 CustomizerHUDView 的数据保存逻辑

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：更新 save() 方法中的双环配置构建**

查找 `save()` 的 `.double` 分支，更新其中的外环配置 `outer`，使其强制同步使用内环的 `translation` 和 `clockwiseAction` 变量：
```swift
        case .double:
            rule.doubleConfig = DoubleKnobConfig(
                inner: VirtualKnobConfig(
                    minRadius: doubleInnerMinRadius,
                    maxRadius: doubleInnerRadiusMax,
                    margin: doubleMargin,
                    unitPerDegree: doubleInnerScale,
                    translation: doubleInnerTranslation,
                    clockwiseAction: doubleInnerCWAction,
                    themeColor: doubleInnerThemeColor
                ),
                outer: VirtualKnobConfig(
                    minRadius: doubleInnerRadiusMax,
                    maxRadius: doubleOuterRadiusMax,
                    margin: doubleMargin,
                    unitPerDegree: doubleOuterScale,
                    translation: doubleInnerTranslation, // 🌟 强制同步内环的映射方式
                    clockwiseAction: doubleInnerCWAction, // 🌟 强制同步内环的映射方向
                    themeColor: doubleOuterThemeColor
                )
            )
```

- [ ] **步骤 2：验证编译**

运行：`swift build`
预期：编译成功，数据同步逻辑就绪。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "feat: sync outer-ring translation and clockwiseAction with inner-ring in save()"
```

---

### 任务 2：重构 doubleBehaviorForm UI 布局

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：整体修改 doubleBehaviorForm，合并 Picker**

将 `doubleBehaviorForm` 里面的两个表单卡片剔除，重构为单一的 Picker 组和两行灵敏度 TextField 调节器。
重构后的结构示例如下：
```swift
    private var doubleBehaviorForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 统一的映射方式
            Picker(String(localized: "hud.outputTranslationPicker", defaultValue: "Output Translation"), selection: $doubleInnerTranslation) {
                ForEach(InputTranslation.allCases, id: \.self) { trans in
                    Text(transDescription(trans)).tag(trans)
                }
            }
            .onChange(of: doubleInnerTranslation) { next in
                doubleInnerCWAction = defaultAction(for: next)
                save()
            }
            
            // 统一的映射方向
            Picker(String(localized: "hud.clockwiseActionPicker", defaultValue: "Clockwise Action"), selection: $doubleInnerCWAction) {
                ForEach(directionOptions(for: doubleInnerTranslation), id: \.self) { opt in
                    Text(actionDescription(opt)).tag(opt)
                }
            }
            .onChange(of: doubleInnerCWAction) { _ in save() }
            
            // 外环与内环灵敏度调节输入框
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "hud.doubleOuterScaleLabel", defaultValue: "外环灵敏度:"))
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Spacer()
                    TextField("", text: $doubleOuterScaleText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: doubleOuterScaleText) { next in
                            if let val = Double(next) {
                                doubleOuterScale = val
                                save()
                            }
                        }
                }
                
                HStack {
                    Text(String(localized: "hud.doubleInnerScaleLabel", defaultValue: "内环灵敏度:"))
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Spacer()
                    TextField("", text: $doubleInnerScaleText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: doubleInnerScaleText) { next in
                            if let val = Double(next) {
                                doubleInnerScale = val
                                save()
                            }
                        }
                }
            }
        }
    }
```

- [ ] **步骤 2：在编译并检测无误后进行 Commit**

运行 `swift build` 编译成功。
```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "feat: simplify doubleBehaviorForm by merging Output Translation and Action direction pickers"
```

---

### 任务 3：系统集成与功能测试

**文件：**
- 修改：`/Users/wb/.gemini/antigravity-ide/brain/5eadebab-19df-4d33-9374-34d87cbe072c/walkthrough.md`

- [ ] **步骤 1：编译并检查项目**

运行 `swift build`。

- [ ] **步骤 2：手工功能测试**
   - 呼出面板。
   - 切换到双环旋钮/旋钮行为。
   - 验证界面仅剩一个公共映射 Picker 和方向 Picker，外环和内环灵敏度仍独立。
   - 更改映射方式，验证退出后重进能够保留。

- [ ] **步骤 3：更新 walkthrough.md 归档并完成**
