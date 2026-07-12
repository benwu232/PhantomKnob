# 旋钮定制面板智能交互与布局优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：**
1. 支持配置面板在毛玻璃背景处可用鼠标自由拖拽；
2. 重构顶栏展示为 PhantomKnob 专属品牌图标和白色大标题，将被控 App 图标与名称移入折叠的“辅助信息”中；
3. 将面板中的四大标题前景色全部改为白色，并统一中文命名；
4. 修复系统调色板变更颜色不保存的 Bug，加入即时持久化和 onDisappear 存档双保险。

**架构：**
1. 在 `CustomizerHUDWindowController.swift` 的 `createWindow(for:)` 中为 `CustomizerWindow` 赋予 `isMovableByWindowBackground = true`。
2. 在 `CustomizerHUDView.swift` 顶栏 HStack 中改用 PhantomKnob 品牌标识图标，显示 “PhantomKnob Customizer” 标题。
3. 重组 `CustomizerHUDView.swift` 的 Section 分类标题：
   - 旋钮类型 -> 前景色设为 `.white`
   - 旋钮外观 -> 前景色设为 `.white`
   - 旋钮行为 -> 前景色设为 `.white`
   - 辅助信息 -> 前景色设为 `.white`（替换原高级定位 DisclosureGroup 标题，并将原顶栏被控 App 图标与名字移入其中首行）
4. 在 `CustomizerHUDView.swift` 中：
   - 监听调色板颜色更改通知 `onReceive(NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification))`，在状态赋值完毕后，在最下方显式加入 `save()`；
   - 在 View 容器的最底端附加 `.onDisappear { save() }` 钩子，确保销毁或退出时，所有修改已持久化。

---

### 任务 1：支持无边框窗口背景鼠标拖动 (Movable By Background)

**文件：**
- 修改：`PhantomKnob/Service/CustomizerHUDWindowController.swift`

- [ ] **步骤 1：为 CustomizerWindow 窗口开启 isMovableByWindowBackground**

在 `createWindow(for:)` 初始化中，窗口对象定义完后，加入以下设置：
```swift
        let win = CustomizerWindow(
            contentRect: calculateWindowFrame(),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isMovableByWindowBackground = true // 🌟 支持鼠标拖动窗口背景
```

- [ ] **步骤 2：运行 swift build 验证编译**

运行：`swift build` 在 `PhantomKnob` 路径下。
预期：编译成功。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/Service/CustomizerHUDWindowController.swift
git commit -m "feat: enable window dragging by background for customizer HUD"
```

---

### 任务 2：重组顶栏 PhantomKnob 品牌展示与四大中文大标题（统一为白色）

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：重构顶栏 Header 布局与图标**

将顶栏 Header 重组，不再显示前台被控应用的图标与名称，改为使用 PhantomKnob 本身的系统图标（如 `gearshape.circle.fill`）和白色标题 “PhantomKnob Customizer”：
```swift
            HStack(spacing: 10) {
                Button(action: {
                    CustomizerHUDWindowController.shared.hide()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.65))
                }
                .buttonStyle(PlainButtonStyle())
                
                // 🌟 使用 PhantomKnob 品牌标识图标与标题
                Image(systemName: "slider.horizontal.3")
                    .resizable()
                    .foregroundColor(.orange)
                    .frame(width: 18, height: 18)
                
                Text("PhantomKnob Customizer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let radius = liveRadius {
                    Text("\(Int(radius)) mm")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Button(action: {
                    isPinned.toggle()
                    CustomizerHUDWindowController.shared.isPinned = isPinned
                }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isPinned ? .blue : .white.opacity(0.65))
                }
                .buttonStyle(PlainButtonStyle())
            }
```

- [ ] **步骤 2：重构 Section 标题的文字、前景色与“辅助信息”折叠**

修改 Section 标题名称为“旋钮类型”、“旋钮外观”、“旋钮行为”，并将前景色全部统一为高对比的**白色**：
```swift
                    // ① 旋钮类型
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "hud.knobType", defaultValue: "旋钮类型"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        ...
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // ② 旋钮外观
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "hud.section.appearance", defaultValue: "旋钮外观"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        ...
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // ③ 旋钮行为
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "hud.section.behavior", defaultValue: "旋钮行为"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        ...
                    }
```

- [ ] **步骤 3：在第四项“辅助信息”中包含被控应用图标和名字，且默认折叠**

修改 `DisclosureGroup`，将其命名为 “辅助信息” 并前景色改为白色。折叠展开后，首行渲染原顶栏的被控应用图标 `appIcon` 和名字 `appName`：
```swift
                    // ④ 辅助信息
                    DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            // 被控应用品牌标识移入辅助信息首行
                            HStack(spacing: 8) {
                                if let icon = appIcon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "app.badge")
                                        .resizable()
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 20, height: 20)
                                }
                                Text(appName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                            
                            // 控件定位元数据
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "hud.locatingIdentifier", defaultValue: "Element Locating Identifier"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                ...
```
作为 Title 按钮：
```swift
                    } label: {
                        Text(String(localized: "hud.section.helper", defaultValue: "辅助信息"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
```

- [ ] **步骤 4：运行 swift build 验证编译**

运行：`swift build`
预期：编译成功，无任何语法错误。

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "feat: redesign customizer panel titles and group original target info into helper disclosure"
```

---

### 任务 3：修复颜色保存缺陷，添加修改即时持久化与 onDisappear 存档双保险

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：在 NSColorPanel.colorDidChangeNotification 监听中即时调用 save()**

在 `onReceive` 调色板改变的通知闭包内，更新完 `themeColor` 属性后，显式执行一次 `save()`：
```swift
        .onReceive(NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification)) { notification in
            print("[CustomizerHUDView] NSColorPanel.colorDidChangeNotification received, object: \(String(describing: notification.object))")
            if let panel = notification.object as? NSColorPanel {
                let color = panel.color
                print("[CustomizerHUDView] panel color: \(color), hex: \(String(describing: color.toHex()))")
                if let hex = color.toHex() {
                    switch activeColorTarget {
                    case .global:
                        self.themeColor = hex
                    case .doubleInner:
                        self.doubleInnerThemeColor = hex
                    case .doubleOuter:
                        self.doubleOuterThemeColor = hex
                    }
                    self.save() // 🌟 立即保存到磁盘，防止退出后面板未更新
                }
            }
        }
```

- [ ] **步骤 2：在主视图容器上附加 onDisappear 钩子执行 save()**

在 `body` 块的最后，为 View 挂上 `.onDisappear`：
```swift
        .onDisappear {
            self.save() // 🌟 退出自定义面板时执行最后一次自动存档双保险
        }
```

- [ ] **步骤 3：运行 swift build 验证编译**

运行：`swift build`
预期：编译成功。

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "fix: call save() immediately on colorDidChange and attach onDisappear double-insurance save"
```

---

### 任务 4：系统整体集成与功能测试

**文件：**
- 修改：`/Users/wb/.gemini/antigravity-ide/brain/5eadebab-19df-4d33-9374-34d87cbe072c/walkthrough.md`

- [ ] **步骤 1：整体编译项目**

运行：`swift build`
预期：Build complete! (0.00s)

- [ ] **步骤 2：测试鼠标拖动**
   - 呼出面板。
   - 按住面板任意空白毛玻璃背景拖拽，验证能顺畅拖动整个窗口在屏幕任意角落定位。

- [ ] **步骤 3：测试白色标题与辅助信息折叠**
   - 验证面板中的 4 大分类标题为高亮白色，且分类字样分别为“旋钮类型”、“旋钮外观”、“旋钮行为”、“辅助信息”。
   - 验证顶栏不再显示目标被控应用，改为显示 PhantomKnob 本身的图标及白色大标题。
   - 点击展开“辅助信息”，验证首行显示了被控应用（如 Finder / 浏览器）的图标和名字。

- [ ] **步骤 4：测试颜色即时保存与退出后持久化**
   - 更改颜色（通过预置圆圈或 Custom Color 调色板）。
   - 验证 Overlay 配色即时更新。
   - 关闭面板（点击关闭或退出自定义）。
   - 重新呼出该控件或进行物理操作，验证 Overlay 完全维持最新配色，持久化修改成功生效！

- [ ] **步骤 5：更新 walkthrough 归档并完成**

将测试结果和最终变化在 `walkthrough.md` 中进行补充总结，整理提交。
