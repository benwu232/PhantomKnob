# 双环旋钮隐藏迟滞带滑块实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：**
1. 移除双环旋钮设置中“迟滞带宽度”这一滑块交互项，保持底层的防抖功能配置读写完全兼容；
2. 保持全局配置表单的清爽度。

---

### 任务 1：从 UI 布局中隐藏迟滞带宽度滑块

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：重构 doubleAppearanceForm，删除 doubleMargin 滑块**

在 `CustomizerHUDView.swift` 的 `doubleAppearanceForm` 中定位 `doubleMargin` 的 Slider，将其删除：
```swift
            // ⚙️ 边界与迟滞范围
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "hud.doubleBoundarySettings", defaultValue: "⚙️ Boundary & Hysteresis Margin"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "hud.boundaryRadius", defaultValue: "Boundary Radius")).font(.system(size: 11))
                        Spacer()
                        Text("\(Int(doubleInnerRadiusMax)) mm")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    Slider(value: $doubleInnerRadiusMax, in: 10.0...40.0, step: 1.0)
                        .onChange(of: doubleInnerRadiusMax) { next in
                            doubleOuterRadiusMin = next
                            save()
                        }
                    
                    // 🌟 移除以下 doubleMargin 调节项：
                    // HStack {
                    //     Text(String(localized: "hud.hysteresisMargin", ...)).font(.system(size: 11))
                    //     Spacer()
                    //     Text("\(Int(doubleMargin)) mm")
                    //         .font(.system(size: 11, design: .monospaced))
                    // }
                    // Slider(value: $doubleMargin, in: 0.0...10.0, step: 1.0)
                    //     .onChange(of: doubleMargin) { next in
                    //         save()
                    //     }
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
```

- [ ] **步骤 2：验证编译**

运行：`swift build`
预期：编译成功。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "feat: hide hysteresis margin doubleMargin slider from CustomizerHUDView"
```

---

### 任务 2：系统集成与功能测试

**文件：**
- 修改：`/Users/wb/.gemini/antigravity-ide/brain/5eadebab-19df-4d33-9374-34d87cbe072c/walkthrough.md`

- [ ] **步骤 1：整体编译项目**

- [ ] **步骤 2：测试验证**
   - 呼出面板。
   - 切换到双环旋钮。
   - 验证仅有“内外环边界”滑块，不再显示“迟滞带宽度”。
   - 验证后台保存逻辑和防抖依然正常起效。

- [ ] **步骤 3：更新 walkthrough.md 归档并完成**
