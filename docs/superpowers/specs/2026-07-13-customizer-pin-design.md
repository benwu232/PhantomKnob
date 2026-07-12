# 旋钮定制面板智能交互与布局优化设计规范

## 1. 业务目标
为了提供极佳的交互连贯性与专业的视觉一致性，对定制面板做如下优化：
1. **拖拽支持**：支持用户直接按住配置面板窗口的任何空白背景进行鼠标拖动，以便自由排布其在屏幕上的位置。
2. **顶栏品牌标识**：原本在顶栏左侧显示的被控第三方应用（如 DaVinci Resolve）图标改回为 `PhantomKnob` 自身的 App 标识，彰显当前定制工具的主体属性。
3. **对比度与中文大标题优化**：分项大标题统一改写为高对比度的**白色**，并将标题的中文固定改为：
   - ① **旋钮类型** (Knob Type)
   - ② **旋钮外观** (Knob Appearance)
   - ③ **旋钮行为** (Knob Behavior)
   - ④ **辅助信息** (Advanced Information, 默认折叠)
4. **辅助信息折叠归集**：原先顶栏的“目标应用图标”和“应用名称”移到“辅助信息”的最上方。折叠展开后即可展示被控 App 详情及“空间定位唯一标识 (Element Locating Identifier)”和层级链信息。

---

## 2. 界面设计 (UI/UX)
- **顶栏**：
  - 左侧：关闭按钮 `xmark.circle.fill`（`.white.opacity(0.65)`）。
  - 中间：`PhantomKnob` 自身的官方应用图标，及“PhantomKnob Customizer”或“旋钮定制面板”白色大标题。
  - 右侧：图钉按钮（`pin`/`pin.fill`，绑定 `isPinned` 状态）。
- **拖动感应**：双击或按住面板空白处的毛玻璃背景即可在全屏范围滑动窗口。
- **大标题**：VStack 的首行分类采用 `.white` 颜色渲染：
  - `Text("旋钮类型")`
  - `Text("旋钮外观")`
  - `Text("旋钮行为")`
  - `Text("辅助信息")` （作为 `DisclosureGroup` 标题）

---

## 3. 详细设计 (Detailed Design)

### 3.1 鼠标拖拽支持
- 在 `CustomizerHUDWindowController.swift` 中的 `createWindow()` 里，直接为 `CustomizerWindow` 设置 `isMovableByWindowBackground` 属性：
  ```swift
  win.isMovableByWindowBackground = true
  ```

### 3.2 顶栏 PhantomKnob 图标与品牌展示
- 在 `CustomizerHUDView.swift` 中，顶栏图标使用主 App 的 `AppIcon` 或通用设置图标，并显示 “PhantomKnob Customizer”：
  ```swift
  Image("AppIcon") // 或使用系统级专属定制图标
      .resizable()
      .frame(width: 24, height: 24)
  Text("PhantomKnob Customizer")
      .font(.system(size: 13, weight: .bold))
      .foregroundColor(.white)
  ```

### 3.3 辅助信息折叠重组
- 将 `DisclosureGroup("辅助信息", isExpanded: $isAdvancedExpanded)` 作为第四项。
- 展开后首行渲染：
  ```swift
  HStack(spacing: 8) {
      if let icon = appIcon {
          Image(nsImage: icon)
              .resizable()
              .frame(width: 20, height: 20)
      }
      Text(appName)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white)
  }
  .padding(.bottom, 4)
  ```
- 接着展示“控件定位唯一标识”的 `Bundle ID`、`AXRole`、`AXIdentifier` 以及冲突特征层级链。

### 3.4 修改即时持久化与生命周期存档机制
为了彻底解决“自定义调色盘修改配色后退出，变回原色”的 Bug：
1. **调色板实时同步**：在 `CustomizerHUDView.swift` 监听 `NSColorPanel.colorDidChangeNotification` 的闭包中，更新完 themeColor 后，必须同步调用一次 `save()` 方法，使颜色修改即时保存到 `my_knobs.json` 磁盘文件中。
2. **生命周期安全存档**：在 `CustomizerHUDView.swift` 的主 View 容器上附加 `.onDisappear` 钩子，在面板退出销毁的瞬间，显式调用一次 `save()` 作为最底层的安全双保险，保证面板的任何修改绝对 100% 被持久化。

---

## 4. 验证计划

### 4.1 手工联调测试
1. 呼出真实 Overlay，按 C 键弹出定制面板。
2. 验证顶栏图标为 PhantomKnob 标志，标题为白色，右上角为灰色空心图钉。
3. 鼠标按住面板背景，验证能自由拖动整个面板在屏幕上任意滑动。
4. 验证面板中的 4 大分类标题（“旋钮类型”、“旋钮外观”、“旋钮行为”、“辅助信息”）字体颜色均为高亮白色。
5. 点击展开“辅助信息”折叠栏：
   - 验证出现当前前台被控应用（例如 QuickTime 或浏览器）的图标和名字。
   - 验证包含“空间定位唯一标识”的 Bundle ID 等详情。
6. 点击图钉并移动主应用，验证面板锁定置顶。
